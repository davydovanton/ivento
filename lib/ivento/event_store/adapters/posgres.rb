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
      class Postgres
        def initialize(db_url)
          @db = Sequel.connect(db_url)
        end

        def get
          groupped_events
        end

        def get_stream(stream)
          groupped_events[stream]
        end

        def append(stream, event)
          @db[:events].insert(event_to_hash(event, stream))
        end

        def append_events(stream, events)
          @db[:events].multi_insert(events.map { |event| event_to_hash(event, stream) })
        end

      private

        def groupped_events
          @db[:events].order(:created_at).all.map do |event|
            Object.const_get(event[:event_name]).new(
              eid: event[:eid],
              stream: event[:stream],
              version: event[:version],
              created_at: event[:created_at],
              payload: JSON.parse(event[:payload], symbolize_names: true)
            )
          end.group_by(&:stream)
        end

        def event_to_hash(event, stream)
          {
            eid: event.eid,
            event_name: event.class.name,
            stream: stream,
            version: event.version,
            created_at: event.created_at,
            payload: event.payload.to_json
          }
        end
      end
    end
  end
end
