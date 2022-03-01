module Arcade
  class Vertex  < Base
   # schema schema.strict    #  -- throws an error if  specified keys are missing
    #transform_keys &:to_sym
    transform_keys{ |x|  x[0] == '@' ? x[1..-1].to_sym : x.to_sym } 
  end
end
