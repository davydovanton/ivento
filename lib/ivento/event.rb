require 'dry-struct'

module Ivento
  module Event
    class Base < Dry::Struct
      module Types
        include Dry::Types.module
      end

      attribute :eid, Types::String.default { SecureRandom.uuid }
      attribute :created_at, Types::Time.default { Time.now }
      attribute :version, Types::String.default('v1').optional
      attribute :stream, Types::String.default('')

      def self.payload_attributes(value = nil)
        if value
          @payload_attributes = Types::Hash.schema(value)
        else
          @payload_attributes || Types::Hash
        end
      end

      attribute :payload, payload_attributes

      def inspect
        "#{self.class.name} (#{version}) (#{eid}) payload: #{data.inspect}"
      end
    end
  end
end
