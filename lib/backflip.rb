require 'backflip/version'

require 'sidekiq/client'
require 'sidekiq/worker'
require 'sidekiq/redis_connection'

module Backflip
  NAME = 'Backflip'
  LICENSE = 'See LICENSE and the LGPL-3.0 for licensing details.'

  Job = Sidekiq::Worker
  Client = Sidekiq::Client
  Middleware = Sidekiq::Middleware

  DEFAULTS = {
    queues: [],
    concurrency: 25,
    require: '.',
    environment: nil,
    timeout: 8,
  }

  def self.options
    @options ||= DEFAULTS.dup
  end

  def self.logger
    Backflip::Logging.logger
  end

  def self.client_middleware
    @client_chain ||= Middleware::Chain.new
    yield @client_chain if block_given?
    @client_chain
  end

  def self.server_middleware
    @server_chain ||= Worker.default_middleware
    yield @server_chain if block_given?
    @server_chain
  end

  def self.server?
    defined?(Backflip::CLI)
  end

  def self.redis(&blk)
    Sidekiq.redis(&blk)
  end

#  def self.redis_pool
#    @redis ||= Sidekiq::RedisConnection.create
#  end

  def self.redis=(hash)
    Sidekiq.redis=(hash)
  end

  def self.terminate
    @cluster.terminate if @cluster and @cluster.alive?
  end

  def self.dispatcher
    @cluster ||= Cluster.run!
    Backflip::Cluster.dispatcher
  end
end

# temporary patches! while one doesn't have a proper queue adapter API
module Sidekiq
  def self.server? ; Backflip.server? ; end
  def self.options ; Backflip.options ; end
  def self.logger  ; Backflip.logger ; end
  VERSION = Backflip::VERSION
end

require 'backflip/logging'
