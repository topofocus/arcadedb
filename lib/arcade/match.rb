module Arcade
  class Match 

    include Arcade::Support::Sql

=begin
  This is a very simple wrapper for the match statement

  Initialize:  a= Arcade::Match.new type: Arcade::DatabaseType, where: { property: 'value' }, as: :alias
  Complete:    b = a.out( Arcade::EdgeType ).node( while: true, as: item )[ .in.node ... ]
  Inspect      b.to_s
  Query DB     b.execute [.allocate_model]
                         [.analyse_result]

=end

    def initialize type: , **args

      @args = args
      @as = []

      @stack = [ "MATCH { type: #{type.database_name}, #{ assigned_parameters } }" ]

      return self
    end

    # Inspect the generated match statement
    def to_s
      r = ""
      r = "DISTINCT " if @distinct
      r << @as.join(",")
      @stack.join("") + " RETURN #{r} "
    end


    # Execute the @stack
    # generally followed by `select_result` to convert json-hashes  to arcade objects
    def execute
      Arcade::Init.db.query self
    end


    # todo : metaprogramming!
    def out edge=""
      raise "edge must be a Database-class"  unless edge.is_a?(Class) || edge.empty?
      @stack << ".out(#{edge.is_a?(Class) ? edge.database_name.to_or : ''})"
      return self
    end
    def in edge=""
      raise "edge must be a Database-class"  unless edge.is_a?(Class) || edge.empty?
      @stack << ".in(#{edge.is_a?(Class) ? edge.database_name.to_or : ''})"
      return self
    end
    def both edge=""
      raise "edge must be a Database-class"  unless edge.is_a?(Class) || edge.empty?
      @stack << ".both(#{edge.is_a?(Class) ? edge.database_name.to_or : ''})"
      return self
    end

    # add conditions on  edges to the match statement
    def inE edge="", **args
      raise "edge must be a Database-class"  unless edge.is_a?(Class) || edge.empty?
      @stack << ".inE(#{edge.is_a?(Class) ? edge.database_name.to_or : ''}) #{assigned_parameters}.outV()"
      return self
    end
    def outE edge="", **args
      raise "edge must be a Database-class"  unless edge.is_a?(Class) || edge.empty?
      @stack << ".outE(#{edge.is_a?(Class) ? edge.database_name.to_or : ''}) #{assigned_parameters}.inV()"
      return self
    end
    def bothE edge="", **args
      raise "edge must be a Database-class"  unless edge.is_a?(Class) || edge.empty?
      @stack << ".bothE(#{edge.is_a?(Class) ? edge.database_name : ''}) #{assigned_parameters}.bothV()"
      return self
    end


    # general declation of a node (ie. vertex)
    def node **args
      @args = args
      @stack << if args.empty?
       "{}"
              else
       "{ #{ assigned_parameters } }"
              end
      return self
    end



    ### ---------------- end of public api ---------------------------------------------------------------- ### 
    private


    def assigned_parameters
      @args.map do | k, v |
      #  unless k == :while  #  mask ruby keyword
        send k, v
      #  else
      #   the_while v
      #  end
      end.compact.join(', ')

    end

    ##  Metastatement     ----------  last  --------------------
    ##
    ## generates a node declaration  for fetching the last element of a traversal on the previous edge
    ##
    ## ie:    Arcade::Match.new( type: self.class, where: { symbol: symbol  } ).out( Arcade::HasContract  )
    #                                                                          .node( as:  :c, where: where  )
    #                                                                          .in( Arcade::IsOrder  )
    #                                                                          .node( last: true, as: :o  )
    #
    #  --> ... }.in('is_order'){ while: (in('is_order').size() > 0), where: (in('is_order').size() == 0), as: o  }
    def last  arg
      in_or_out = @stack[-1][1..-1]   # use the last statement
      "while: ( #{in_or_out}.size() > 0  ), where: (#{in_or_out}.size() == 0)"
    end

    def distinct arg
      @distinct = true
    end


    def where arg
      "where: ( #{ generate_sql_list( arg  )  } )" unless arg.empty?
    end

    def while arg
      if arg.is_a? TrueClass
         "while: ( true )"
       else
       "while: ( #{ generate_sql_list( arg  ) } )"
       end
    end

    def maxdepth arg
      "maxDepth: #{arg}"
    end

    def as arg
      @as << arg
      "as: " + arg.to_s
    end

    def type klassname
      raise "type must be a Database-class"  unless klassname.is_a? Class
      "type: #{klassname.database_name}"
    end

  end
end
