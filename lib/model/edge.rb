module Arcade
  class Edge  <  Base
   # schema schema.strict    #  -- throws an error if  specified keys are missing
    attribute :in, Types::Rid
    attribute :out, Types::Rid

    # Add Contrains to the edge
    # CREATE INDEX Watched_out_in ON <edge type«  (`@out`, `@in`) UNIQUE
    #
    #attribute :in?, Types::Nominal::Any
    #attribute :out?, Types::Nominal::Any
    def self.create  from:, to:, **attr
        db.create_edge  database_name, from: from, to: to, **attr
    end

    ## gets the adjacent Vertex
    def inV
      attributes[:in].load_rid
    end
    def outV
      attributes[:out].load_rid
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
