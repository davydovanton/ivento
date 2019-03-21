# Simple implementation of event store
#
# Interface:
#   Get : unit -> event list
#   Append : event list -> unit
#   Evolve : event producer (event) -> unit
#
# Based on Concurrent/Actor

require 'concurrent'
require 'concurrent/actor'
require 'securerandom'
require 'sequel'

module Ivento
  class EventStore
    class Subscriber
      def initialize(event_class, block)
        @event_class = event_class
        @block = block
      end

      def call(event)
        @block.call(event) if @event_class.name == event.class.name
      end
    end
  end
end
