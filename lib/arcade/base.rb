module Arcade
  class Base  < Dry::Struct

    # schema schema.strict    #  -- throws an error if  specified keys are missing
    transform_keys{ |x|  x[0] == '@' ? x[1..-1].to_sym : x.to_sym }
    # only accept  #000:000,  raises an Error, if rid is not present
    attribute :rid, Types::Rid
    # maybe there are edges
    attribute :in?, Types::Nominal::Any
    attribute :out?, Types::Nominal::Any

    class << self

      # this has to be implemented on class level
      # otherwise it interferes with attributes
      def database_name
        self.name.snake_case
      end

      def insert **attributes
        db.execute { "insert into #{database_name} CONTENT #{attributes.to_json}" }
      end

      alias create insert

      def all
        db.query "select from #{database_name}"
      end
    end
  end
end
