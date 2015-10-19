class UnitOfWork
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

