module Backflip
  class Dispatcher
    include Celluloid::IO

    finalizer :done

    TIMEOUT = 1

    def initialize
      @down = nil
      @done = false
      @strategy = BasicFetch.new(Backflip.options)
      @busy = 0
    end

    def start
      async(:fetch)
    end

    def stop
      # marks dispatcher as ready to leave, no subsequent work will be assigned
      @done = true 
    end

    def fetch
      return if @done or @busy >= Backflip.options[:concurrency]
      begin
        job = @strategy.retrieve_job
        Backflip.logger.info("Redis is online, #{Time.now - @down} sec downtime") if @down
        @down = nil

        if job
           async(:assign, job)
        else
          after(0) { fetch }
        end
      rescue => ex
        handle_fetch_exception(ex)
      end
    end

    def assign(job)
      return unless job
      # you have to have the guarantee that this method is the only one where one is 
      # handling with the workers container
      worker = Cluster.workers.shift
      Cluster.workers << worker

      @busy += 1

      # the semaphore is here for lightning-fast jobs which signal before the job
      # suspends. It's therefore important to guarantee the early suspension kickstart as
      # an actor event.       
      semaphore = future { job.suspend }
      worker.async(:do!, job)
      semaphore.value

      @busy -= 1
      async(:fetch)
    end

    private

    def pause
      sleep(TIMEOUT)
    end

    def handle_fetch_exception(ex)
      if !@down
        Backflip.logger.error("Error fetching message: #{ex}")
        ex.backtrace.each do |bt|
          Backflip.logger.error(bt)
        end
      end
      @down ||= Time.now
      pause
      # after(0) { fetch } # TODO: isn't an error here?
    rescue Celluloid::TaskTerminated
      # If redis is down when we try to shut down, all the fetch backlog
      # raises these errors.  Haven't been able to figure out what I'm doing wrong.
    end
  end

  class BasicFetch
    def initialize(options)
      @strictly_ordered_queues = !!options[:strict]
      @queues = options[:queues].map { |q| "queue:#{q}" }
      @unique_queues = @queues.uniq
    end

    def retrieve_job
      work = Backflip.redis do |conn| 
        conn.brpop(*queues_cmd)
      end
      UnitOfWork.new(*work) if work
    end

    # By leaving this as a class method, it can be pluggable and used by the Manager actor. Making it
    # an instance method will make it async to the Fetcher actor
    def self.bulk_requeue(inprogress, options)
      return if inprogress.empty?

      Backflip.logger.debug { "Re-queueing terminated jobs" }
      jobs_to_requeue = {}
      inprogress.each do |unit_of_work|
        jobs_to_requeue[unit_of_work.queue_name] ||= []
        jobs_to_requeue[unit_of_work.queue_name] << unit_of_work.message
      end

      Backflip.redis do |conn|
        conn.pipelined do
          jobs_to_requeue.each do |queue, jobs|
            conn.rpush("queue:#{queue}", jobs)
          end
        end
      end
      Backflip.logger.info("Pushed #{inprogress.size} messages back to Redis")
    rescue => ex
      Backflip.logger.warn("Failed to requeue #{inprogress.size} jobs: #{ex.message}")
    end

    UnitOfWork = Class.new do
      attr_reader :queue, :message
      def initialize(queue, message)
        @queue = queue
        @message = message
        @condition = Celluloid::Condition.new
      end

      def suspend
        @condition.wait
      end

      def signal
        @condition.signal 
      end

      def queue_name
        queue.gsub(/.*queue:/, '')
      end

      def requeue
        Backflip.redis do |conn|
          conn.rpush("queue:#{queue_name}", message)
        end
      end
    end

    # Creating the Redis#brpop command takes into account any
    # configured queue weights. By default Redis#brpop returns
    # data from the first queue that has pending elements. We
    # recreate the queue command each time we invoke Redis#brpop
    # to honor weights and avoid queue starvation.
    def queues_cmd
      queues = @strictly_ordered_queues ? @unique_queues.dup : @queues.shuffle.uniq
      queues << Backflip::Dispatcher::TIMEOUT
    end
  end
end
