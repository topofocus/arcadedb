module Arcade
  class Edge  <  Base
   # schema schema.strict    #  -- throws an error if  specified keys are missing
    attribute :in, Types::Rid
    attribute :out, Types::Rid

    def accepted_methods
      super + [ :vertices, :in, :out, :inV, :outV ]
    end
    #
    # Add Contrains to the edge
    # CREATE INDEX Watched_out_in ON <edge type«  (`@out`, `@in`) UNIQUE
    #
    def self.create  from:, to:, **attr
        db.create_edge  database_name, from: from, to: to, **attr
    end

    def delete
      db.execute{  "delete edge #{ rid }" }
    end
    ## gets the adjacent Vertex
    def inV
      query( projection: "inV()").query.select_result
    end
    def outV
      query( projection: "outV()").query.select_result
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
