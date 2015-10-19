require 'backflip/version'

module Backflip
  NAME = 'Backflip'
  LICENSE = 'See LICENSE and the LGPL-3.0 for licensing details.'

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
end

require 'backflip/logging'
