module Arcade
  class Match 

    include Arcade::Support::Sql

=begin
  This is a wrapper for the match statement

  Initialize:  a= Arcade::Match.new type: Arcade::DatabaseType, where: { property: 'value' }, as: :alias
  Complete:    b = a.out( Arcade::EdgeType ).node( while: true, as: item )[ .in.node ... ]
  Inspect      b.to_s
  Query DB     b.execute [.allocate_model]
                         [.analyse_result]
  Customize the return values:
               b.to_s{ "customized return statement" }
               b.execute{ "customized return statment" }
               
  Conditions on edges:
        m =  Match.new type: Arcade::DatabaseType
        m.inE via: Arcade::Edge  || via: [Arcade::Edge1, Arcade::Edge2], where: { var: 3..6 }  
         --->  inE('edge(1)'){ where: (var between 3 and 6 )}.outV('edge(2)')

  Address a single database record:
        m = Match.new( vertex: { Arcade::Vertex-Instance } )
            .....
            .node( vertex: { Arcade::Vertex-Instance } )     # instead of where statement           

  Example

   symbol_or_title =  symbol.present? ? { :symbol => symbol } : { :title => title }
   where = { :right => right }

   a= Arcade::Match.new( type: self.class, where: symbol_or_title )
                   .out( Arcade::HasContract )
                   .node( as: :c, where: where )
   a.execute do "c.last_trading_day as expiry,         # c is returned form the query [as: :c]                                               
                 count(c) as contracts,
                 min(c.strike) as s_min,
                 max(c.strike) as s_max
                 group by c.last_trading_day order by c.last_trading_day"
             end


=end

    def initialize  **args
      type = args.delete :type
      vertex =  args.delete :vertex
      rid =  args.delete :rid
      raise "MATCH#new:: parameter rid is not supported. Use `vertex: Arcade::Vertex.instance` instead." if rid.present?
      @args = args
      @as = []

      @stack = if vertex.is_a?( Arcade::Vertex ) && args.empty?
         [ "MATCH { type: #{vertex.class.database_name }, rid: #{vertex.rid} }" ]
               elsif  vertex.is_a?( Arcade::Vertex ) 
         [ "MATCH { type: #{vertex.class.database_name }, rid: #{vertex.rid}, #{ assigned_parameters } }" ]
               elsif  type.is_a?( Class) && type.ancestors.include?(Arcade::Vertex) && args.empty?
         [ "MATCH { type: #{type.database_name} }" ]
               elsif  type.is_a?( Class) && type.ancestors.include?(Arcade::Vertex)
         [ "MATCH { type: #{type.database_name}, #{ assigned_parameters } }" ]
               else
         raise "Match:: Either type  (Arcade::Vertex-Class) or vertex (Arcade::Vertex-Object) is required as parameter"
               end

      return self
    end

    # Inspect the generated match statement
    def to_s &b
      r = ""
      r = "DISTINCT " if @distinct
      r << @as.join(",")
      r= yield(r) if block_given?
      @stack.join("") + " RETURN #{r} "
    end


    # Execute the @stack
    # generally followed by `select_result` to convert json-hashes  to arcade objects
    #
    # The optional block  modifies the result-statement
    # i.e
    # TG::TimeGraph.grid( 2023, 2..9  ).out(HasPosition)
    #                                  .node( as: :contract  )
    #                                  .execute { "contract.symbol"  }
    #                                  .select_result
    # gets all associated contracts connected to the month-grid
    def execute &b
      Arcade::Init.db.query( to_s( &b ) )
    end



    def self.define_base_edge *direction
      direction.each do | e_d |
        define_method e_d do | edge = "" |
          raise "edge must be a Database-class" unless edge.is_a?(Class) || edge.empty?
          @stack << ".#{ e_d  }(#{edge.is_a?(Class) ? edge.database_name.to_or : ''})"
          self
        end
      end
    end


    # add conditions on  edges to the match statement
    def self.define_inner_edge start_dir, final_dir
      define_method start_dir do | edge = "", **a |
        raise "edge must be a Database-class"  unless edge.is_a?(Class) || edge.empty?

        print_edges = -> (e){ e.is_a?(Class) ? e.database_name.to_or : ''}
        edges = [ a.delete(:via) ].flatten
        edges << edge unless edge == ''
        n = if a.empty?
              ""
            else
              @args = a
              "{ #{ assigned_parameters } }"
            end
        @stack << ".#{ start_dir }(#{print_edges.call(edges.first)})#{ n }.#{ final_dir }(#{print_edges.call(edges.last)})"
        return self
      end

    end

    define_base_edge :out, :in, :both
    define_inner_edge :inE, :outV
    define_inner_edge :outE, :inV



    # general declation of a node (ie. vertex)
    def node **args
      vertex =  args.delete :vertex
      rid =  args.delete :rid
      raise "MATCH#node:: parameter rid is not supported. Use `vertex: Arcade::Vertex.instance` instead." if rid.present?
      @args = args
      @stack << if args.empty?
       vertex.present? ? "{ type: #{vertex.class.database_name }, rid: #{vertex.rid} }" : "{}"
                else
       vertex.present? ? "{ type: #{vertex.class.database_name }, rid: #{vertex.rid}, #{assigned_parameters} }" :  "{ #{ assigned_parameters } }"
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
