require 'time'
require 'logger'

module Backflip
  module Logging

    class Pretty < Logger::Formatter
      SPACE = " "

      # Provide a call() method that returns the formatted message.
      def call(severity, time, program_name, message)
        "#{time.utc.iso8601(3)} #{::Process.pid} TID-#{Thread.current.object_id.to_s(36)}#{context} #{severity}: #{message}\n"
      end

      def context
        c = Thread.current[:sidekiq_context]
        " #{c.join(SPACE)}" if c && c.any?
      end
    end

    class WithoutTimestamp < Pretty
      def call(severity, time, program_name, message)
        "#{::Process.pid} TID-#{Thread.current.object_id.to_s(36)}#{context} #{severity}: #{message}\n"
      end
    end

    def self.with_context(msg)
      Thread.current[:sidekiq_context] ||= []
      Thread.current[:sidekiq_context] << msg
      yield
    ensure
      Thread.current[:sidekiq_context].pop
    end

    def self.initialize_logger(log_target = STDOUT)
      oldlogger = defined?(@logger) ? @logger : nil
      @logger = Logger.new(log_target)
      @logger.level = Logger::INFO
      @logger.formatter = ENV['DYNO'] ? WithoutTimestamp.new : Pretty.new
      oldlogger.close if oldlogger 
      @logger
    end

    def self.logger
      defined?(@logger) ? @logger : initialize_logger
    end

    def self.logger=(log)
      @logger = (log ? log : Logger.new('/dev/null'))
    end

    def logger
      Backflip::Logging.logger
    end
  end
end
