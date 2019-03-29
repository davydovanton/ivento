require 'concurrent'
require 'concurrent/actor'
require 'securerandom'
require 'sequel'

module Ivento
  class EventStore
    class MessageBox < Concurrent::Actor::Context
      def initialize(adapter: Adapters::Memory.new, logger: Logger.new(STDOUT))
        @adapter = adapter
        @logger = logger
        @subscribers = []
      end

      def on_message(message)
        @logger.info(message[:type])

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
  end
end
