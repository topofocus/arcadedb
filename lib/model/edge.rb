module Arcade
  class Edge  <  Base
   # schema schema.strict    #  -- throws an error if  specified keys are missing
    attribute :in, Types::Rid
    attribute :out, Types::Rid

    def self.create  from:, to:, **attr
        db.create_edge  database_name, from: from, to: to, **attr
    end

    ## gets the adjacent Vertex
    def inV
     db.get(attributes[:in])
    end
    def outV
     db.get(attributes[:out])
    end
    def vertices in_or_out = nil
      case in_or_out
      when :in
        inV
      when :out
        outV
      else
        [inV, outV]
      end
    end

    alias bothV vertices


    def to_human
      "<#{self.class.to_s.snake_case}[#{rid}] :.: #{ out }->#{invariant_attributes}->#{ attributes[:in] }>"
    end
  end
end
