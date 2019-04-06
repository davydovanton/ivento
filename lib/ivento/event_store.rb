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

require "ivento/event_store/message_box"
require "ivento/event_store/subscriber"

# TODO: fix require

module Ivento
  class EventStore
    # TODO: fix DI for message box
    def initialize(adapter)
      @message_box = EventStore::MessageBox.spawn(:message_box, adapter: adapter)
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
  end
end
