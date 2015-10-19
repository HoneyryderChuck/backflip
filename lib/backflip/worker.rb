require 'json'
require 'sidekiq/middleware/server/retry_jobs'
require 'sidekiq/middleware/server/logging'

module Backflip
  class Worker
    include Celluloid::IO

    def self.default_middleware
      Middleware::Chain.new do |m|
        m.add Sidekiq::Middleware::Server::Logging
        m.add Sidekiq::Middleware::Server::RetryJobs
        if defined?(::ActiveRecord::Base)
          require 'sidekiq/middleware/server/active_record'
          m.add Sidekiq::Middleware::Server::ActiveRecord
        end
      end
    end

    def do!(job)
      # let's blatantly copy this, for now

      msgstr = job.message
      queue = job.queue_name

      begin
        msg = JSON.parse(msgstr)
        klass  = msg['class'.freeze].constantize
        work = klass.new
        work.jid = msg['jid'.freeze]

        Backflip.server_middleware.invoke(work, msg, queue) do
          work.perform(*msg['args'.freeze].dup)
        end
      rescue Exception => ex
        #handle_exception(ex, msg || { :message => msgstr })
        raise
      ensure
        job.signal
      end
    end
  end
end
