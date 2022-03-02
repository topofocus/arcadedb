module Arcade
  class Base  < Dry::Struct
   # schema schema.strict    #  -- throws an error if  specified keys are missing
    transform_keys{ |x|  x[0] == '@' ? x[1..-1].to_sym : x.to_sym } 
    # only accept  #000:000
    attribute :rid, Types::Rid
    # maybe there are edges
    attribute :in?, Types::Nominal::Any
    attribute :out?, Types::Nominal::Any
  end
end
