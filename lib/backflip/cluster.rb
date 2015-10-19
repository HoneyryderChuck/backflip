require 'backflip/dispatcher'
require 'backflip/worker'

module Backflip
  class Cluster < Celluloid::Supervision::Container
    class << self

      def dispatcher
        @dispatcher ||= Celluloid::Actor[:"backflip_dispatcher"]
      end

      def workers
        @workers ||= max_workers.map { |i| ::Celluloid::Actor[:"backflip_worker_#{i}"] }
      end

      def max_workers
        1..([2, ::Celluloid::cores-1].max)
      end

    end


    max_workers.each do |i| 
      supervise type: Worker, as: :"backflip_worker_#{i}"
    end

    supervise type: Dispatcher, as: :backflip_dispatcher

    def start
      
    end
  end
end
