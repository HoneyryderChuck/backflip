# encoding: utf-8
$stdout.sync = true

require 'yaml'
require 'singleton'
require 'optparse'
require 'erb'
require 'fileutils'

require 'backflip'

module Backflip
  class Shutdown < Interrupt; end

  class CLI
    include Singleton


    def initialize
      @code = nil
    end

    def parse(args=ARGV)
      @code = nil

      setup_options(args)
      initialize_logger
      validate!
      load_celluloid
    end

    def run
      boot_system
      print_banner

      self_read, self_write = IO.pipe

      %w(INT TERM USR1 USR2 TTIN).each do |sig|
        begin
          trap sig do
            self_write.puts(sig)
          end
        rescue ArgumentError
          puts "Signal #{sig} not supported"
        end
      end

      Backflip.logger.info "Running in #{RUBY_DESCRIPTION}"
      Backflip.logger.info Backflip::LICENSE

#      fire_event(:startup)

      Backflip.logger.debug {
        "Middleware: #{Backflip.server_middleware.map(&:klass).join(', ')}"
      }

#      Backflip.redis do |conn|
#        # touch the connection pool so it is created before we
#        # launch the actors.
#      end

      Backflip.logger.info 'Starting processing, hit Ctrl-C to stop'

#      require 'backflip/launcher'
#      launcher = Backflip::Launcher.new(options)

      begin
#        launcher.run

        while readable_io = IO.select([self_read])
          signal = readable_io.first[0].gets.strip
          handle_signal(signal)
        end
      rescue Interrupt
        Backflip.logger.info 'Shutting down'
#        launcher.stop
#        fire_event(:shutdown, true)
        # Explicitly exit so busy Processor threads can't block
        # process shutdown.
        exit(0)
      end
    end

    def self.banner
      # TODO: find a cool banner
    end

    def handle_signal(sig)
      Backflip.logger.debug "Got #{sig} signal"
      case sig
      when 'INT'
        # Handle Ctrl-C in JRuby like MRI
        # http://jira.codehaus.org/browse/JRUBY-4637
        raise Interrupt
      when 'TERM'
        # Heroku sends TERM and then waits 10 seconds for process to exit.
        raise Interrupt
      when 'USR1'
        Backflip.logger.info "Received USR1, no longer accepting new work"
#        launcher.manager.async.stop
#        fire_event(:quiet, true)
      when 'TTIN'
        Thread.list.each do |thread|
          Backflip.logger.warn "Thread TID-#{thread.object_id.to_s(36)} #{thread['label']}"
          if thread.backtrace
            Backflip.logger.warn thread.backtrace.join("\n")
          else
            Backflip.logger.warn "<no backtrace available>"
          end
        end
      end
    end

    private

    def print_banner
      # Print logo and banner for development
      if $stdout.tty?
        puts "\e[#{31}m"
        puts Backflip::CLI.banner
        puts "\e[0m"
      end
    end

    def load_celluloid
      # TODO: maybe remove this from here. Celluloid initialization no longer sets up threads
      # and random actors which might cause a fork problem. Require at will, just be sure you 
      # allow forking until you create your first actors. 
      require 'celluloid/current'
      Celluloid.logger = (options[:verbose] ? Backflip.logger : nil)

#      require 'backflip/manager'
#      require 'backflip/scheduled'
    end


    def setup_options(args)
      opts = parse_options(args)

      opts[:strict] = true if opts[:strict].nil?

      options.merge!(opts)
    end

    def options
      Backflip.options
    end

    def boot_system
      # TODO: maybe remove this. A check on the required file already happens in validate! step. 
      raise ArgumentError, "#{options[:require]} does not exist" unless File.exist?(options[:require])

      require options[:require]
    end

    def default_tag
      dir = ::Rails.root
      name = File.basename(dir)
      if name.to_i != 0 && prevdir = File.dirname(dir) # Capistrano release directory?
        if File.basename(prevdir) == 'releases'
          return File.basename(File.dirname(prevdir))
        end
      end
      name
    end

    def validate!
      options[:queues] << 'default' if options[:queues].empty?

      if !File.exist?(options[:require])# ||
#         (File.directory?(options[:require]) && !File.exist?("#{options[:require]}/config/application.rb"))
        Backflip.logger.info "=================================================================="
        Backflip.logger.info "  Please point backflip to a Rails 3/4 application or a Ruby file  "
        Backflip.logger.info "  to load your worker classes with -r [DIR|FILE]."
        Backflip.logger.info "=================================================================="
        exit(1)
      end

      [:concurrency, :timeout].each do |opt|
        raise ArgumentError, "#{opt}: #{options[opt]} is not a valid value" if options.has_key?(opt) && options[opt].to_i <= 0
      end
    end

    def parse_options(argv)
      opts = {}

      parser = OptionParser.new do |o|
        o.on '-c', '--concurrency INT', "concurrent jobs to accomplish" do |arg|
          opts[:concurrency] = Integer(arg)
        end

        o.on '-e', '--environment ENV', "Application environment" do |arg|
          opts[:environment] = arg
        end

        o.on '-g', '--tag TAG', "Process tag for procline" do |arg|
          opts[:tag] = arg
        end

        o.on '-i', '--index INT', "unique process index on this machine" do |arg|
          opts[:index] = Integer(arg.match(/\d+/)[0])
        end

        o.on "-q", "--queue QUEUE[,WEIGHT]", "Queues to process with optional weights" do |arg|
          queue, weight = arg.split(",")
          parse_queue opts, queue, weight
        end

        o.on '-r', '--require [PATH|DIR]', "File to require" do |arg|
          opts[:require] = arg
        end

        o.on '-t', '--timeout NUM', "Shutdown timeout" do |arg|
          opts[:timeout] = Integer(arg)
        end

        o.on "-v", "--verbose", "Print more verbose output" do |arg|
          opts[:verbose] = arg
        end

#        o.on '-C', '--config PATH', "path to YAML config file" do |arg|
#          opts[:config_file] = arg
#        end

        o.on '-V', '--version', "Print version and exit" do |arg|
          puts "backflip #{Backflip::VERSION}"
          exit(0)
        end
      end

      parser.banner = "backflip [options]"
      parser.on_tail "-h", "--help", "Show help" do
        Backflip.logger.info parser
        exit(1)
      end
      parser.parse!(argv)
      opts
    end

    def initialize_logger
      Backflip::Logging.initialize_logger

      Backflip.logger.level = ::Logger::DEBUG if options[:verbose]
    end


    def parse_queues(opts, queues_and_weights)
      queues_and_weights.each { |queue_and_weight| parse_queue(opts, *queue_and_weight) }
    end

    def parse_queue(opts, q, weight=nil)
      [weight.to_i, 1].max.times do
       (opts[:queues] ||= []) << q
      end
      opts[:strict] = false if weight.to_i > 0
    end
  end
end
