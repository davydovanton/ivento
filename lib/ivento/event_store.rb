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

# TODO: fix require

module Ivento
  class EventStore
    # TODO: fix DI for message box
    def initialize(message_box = MessageBox.spawn(name: :message_box))
      @message_box = message_box
    end

    def get
      @message_box.ask(type: :get).value
    end

    def get_stream(stream)
      @message_box.ask(type: :get_stream, stream: stream).value
    end

    def append(stream, *events)
      events.each { |event| @message_box.tell(type: :append, stream: stream, event: event) }
    end

    def evolve(stream, producer, payload)
      @message_box.ask(type: :evolve, stream: stream, producer: producer, payload: payload)
    end

    def subscribe(event_class, &block)
      @message_box.ask(type: :subscribe, event_class: event_class, subscriber_block: block)
    end

  private

    class Subscriber
      def initialize(event_class, block)
        @event_class = event_class
        @block = block
      end

      def call(event)
        @block.call(event) if @event_class.name == event.class.name
      end
    end

    class MessageBox < Concurrent::Actor::Context
      def initialize
        @adapter = Adapters::Psql.new
        @subscribers = []
      end

      def on_message(message)
        case message[:type]
        when :get
          @adapter.get
        when :get_stream
          @adapter.get_stream(message[:stream])
        when :append
          @adapter.append(message[:stream], message[:event])

          @subscribers.each { |s| s.call(message[:event]) }
        when :evolve
          current_events = @adapter.get_stream(message[:stream])
          new_events = message[:producer].call(current_events, message[:payload])
          @adapter.append_events(message[:stream], new_events)

          new_events.each { |event| @subscribers.each { |s| s.call(event) } }
        when :subscribe
          @subscribers << Subscriber.new(message[:event_class], message[:subscriber_block])
        else
          # pass to ErrorsOnUnknownMessage behaviour, which will just fail
          pass
        end
      end
    end

    module Adapters
      class InMemory
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

      class Psql
        # TODO: Use config object here
        def initialize
          @db = Sequel.connect('postgres://localhost/todo_app_event_sourcing')
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
