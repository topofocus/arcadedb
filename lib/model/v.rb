module Arcade
  class Vertex  < Dry::Struct
   # schema schema.strict    #  -- throws an error if  specified keys are missing
    transform_keys &:to_sym
    # only accept  #000:000
    attribute :rid, Types::String.constrained( format:  /\A[#]{1}[0-9]{1,}:[0-9]{1,}\z/ )
    # maybe there are edges
    attribute :in?, Types::Nominal::Any
    attribute :out?, Types::Nominal::Any

  end
end
