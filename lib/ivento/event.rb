require 'dry-struct'

module Ivento
  module Event
    module Types
      include Dry::Types.module
    end

    module Events
      class Base < Dry::Struct
        attribute :eid, Types::String.default { SecureRandom.uuid }
        attribute :created_at, Types::Time.default { Time.now }
        attribute :version, Types::String.default('v1').optional
        attribute :stream, Types::String.default('')

        def self.data_attributes(value = nil)
          if value
            @data_attributes = Types::Hash.schema(value)
          else
            @data_attributes || Types::Hash
          end
        end

        attribute :data, data_attributes

        def inspect
          "#{self.class.name} (#{version}) (#{eid}) payload: #{data.inspect}"
        end
      end
    end
  end
end
