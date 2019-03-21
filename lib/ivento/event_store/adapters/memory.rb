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
    module Adapters
      class Memory
        def initialize
          @store = Concurrent::Hash.new { [] }
        end

        def get
          @store
        end

        def get_stream(stream)
          @store[stream]
        end

        def append(stream, event)
          @store[stream] << event
        end

        def append_events(stream, events)
          @store[stream] = @store[stream] + events
        end
      end
    end
  end
end
