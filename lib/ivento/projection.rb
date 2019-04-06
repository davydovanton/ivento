module Ivento
  module Projections
    class Project
      def call(projection, base_state, events)
        fail("Invalid type for events: #{events.inspect}")  unless events.is_a?(Array)
        events.reduce(base_state) { |state, event| projection.call(state, event) }
      end
    end
  end
end
