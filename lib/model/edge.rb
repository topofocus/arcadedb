module Arcade
  class Edge  <  Base
   # schema schema.strict    #  -- throws an error if  specified keys are missing
    attribute :in?, Types::Nominal::Any
    attribute :out?, Types::Nominal::Any

  end
end
