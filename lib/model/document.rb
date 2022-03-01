module Arcade
  class Document  < Dry::Struct
   # schema schema.strict    #  -- throws an error if  specified keys are missing
    #transform_keys &:to_sym
    transform_keys{ |x| x[0] == '@' ? x[1..-1].to_sym : x.to_sym } 
    # only accept  #000:000
    attribute :rid, Types::String.constrained( format:  /\A[#]{1}[0-9]{1,}:[0-9]{1,}\z/ )
    attribute :values, Types::Hash.optional
    attribute :in?, Types::Nominal::Any
    attribute :out?, Types::Nominal::Any

  end
end
