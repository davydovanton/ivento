module Ivento
  module Projections
    class Project
      def call(projection, base_state, events)
        events.reduce(base_state) { |state, event| projection.call(state, event) }
      end
    end
  end
end
