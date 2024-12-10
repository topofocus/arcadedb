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
    rescue Arcade::QueryError => e
      if  e.message =~ /Duplicated key\s+.+\sfound on index/
        if e.args.keys.first == :exceptionArgs
          # return the  previously assigned edge
          e.args[:exceptionArgs].split('|').last.load_rid
        else
          raise
        end
      else
        raise
       end

    end


    ## class-method: Delete Edge between two vertices
    ##
    ## returns the count of deleted edges
    ##
    ## todo: add conditions
    def self.delete from:, to:
      return 0 if from.nil? || to.nil?
      raise "parameter ( from: ) must be a String or a Vertex" unless from.is_a?(String) || from.is_a?( Arcade::Vertex)
      raise "parameter ( to: ) must be a String or a Vertex" unless to.is_a?(String) || to.is_a?( Arcade::Vertex)
      raise "parameters (from: + to:) must respond to `.rid`" unless from.respond_to?( :rid) && to.respond_to?(:rid)

      db.execute{ "delete edge from #{from.rid} to #{to.rid} " } &.select_result &.first
    end


    ## instance method: Delete specified edge
    def delete
      db.execute{  "delete edge #{ rid }" }.select_result
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
