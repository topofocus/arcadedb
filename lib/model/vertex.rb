module Arcade
  class Vertex  < Base

#    include Arcade::Support::Sql
    include Arcade::Support::Model   #  instance methods
    extend Arcade::Support::Model    #  class methods

    attribute :in?, Types::Nominal::Any
    attribute :out?, Types::Nominal::Any
    #                                                                                               #
    def accepted_methods
     super + [ :in, :out, :both, :edges, :inE, :outE, :bothE,  :assign]
    end
    ## ----------------------------------------- Class Methods------------------------------------ ##
    #                                                                                               #

=begin
   Creates a Vertex-Instance.
   Similar to `Vertex#insert`.

   Difference is the presence of a `created` property, a timestamp set to the time and date of creation.
=end

    def self.create timestamp: true, **args
      #t= timestamp ?  ", created = Date(#{DateTime.now.to_i}) "  : ""
      t= timestamp ?  ", created = sysdate() "  : ""
     # db.transmit { "create VERTEX #{database_name} set #{args.map{|x,y| [x,y.to_or].join("=")}.join(', ')+t}" } &.first.allocate_model(false)
     Api.create_document  db.database, database_name, session_id: db.session,  **args
    end


=begin
    Vertex.delete fires a "delete vertex" command to the database.
    To remove all records  use  »all: true« as argument
    To remove a specific rid, use  rid: "#nn:mmm" as argument

    The "where" parameter is optional

    Example:
    ExtraNode.delete where: { item: 67   }  == ExtraNode.delete item: 67
=end
    def self.delete where: {} , **args
      if args[:all] == true
        where = {}
      elsif args[:rid].present?
        return db.transmit { "delete from #{args[:rid]}"  }.first["count"]
      else
        where.merge!(args) if where.is_a?(Hash)
        return 0 if where.empty?
      end
      # query returns [{count => n }]
      #  puts "delete from  #{database_name} #{compose_where(where)}"
      db.transmit { "delete  from `#{database_name}` #{compose_where(where)}"   } &.first[:count] rescue 0
    end

## get adjacent nodes based on a query on the actual model


    def self.nodes in_or_out = :both, via: nil ,  **args

      s =  Query.new from: self
      s.nodes in_or_out, via: via, **args
      s.query &.select_result
    end


    #                                                                                               #
    ## ---------------------------------   Instance    Methods   --------------------------------- ##
    #
    #  We need expand as fallback if a vertex, which is stored as link, is automatically loaded
    #
      def expand
        self
      end
    #  ---------------------------------   Nodes   ----------------------------------------------- #
      #  fetches adjacet nodes
      #  supported
      #  nodes  in_or_out =  :in, :out, :both, :inE, :outE
      #         depth     =  fetch the n'th node through travese
      #         via:      =  Arcade Database Type (the ruby class)
      #         where:    =  a condition
      #                      inE, outE  -->  matches attributes on the edge
      #                      in, out, both -> matches attributes on the adjacent vertex
      #  Example  Strategie.first nodes  where: {size: 10}
      #  "select  both()[ size = 10  ]  from #113:8 "
      #
    def nodes in_or_out=:both, depth= 1, via: nil , execute: true, **args
      if depth <= 1
        s= query.nodes in_or_out, via: via, **args
        execute ? s.query &.select_result : s
      else
       travese in_or_out, depth: depth, start_at: depth-1, via: via, execute: execute, where: args[:where]
      end
    end

    # Supports where: { where condition for edges }
    def edges in_or_out = :both, depth= 1, via: nil , execute: true

      v = in_or_out.to_s.delete_suffix 'E'
      e = v + 'E'
      edge_name = via.nil? ? "" : resolve_edge_name( via )
      argument =  "#{e}(#{edge_name})"
      q= if depth > 1
            repeated_argument = Array.new(depth -1 , "#{v}(#{edge_name})").join(".")
            query.projection repeated_argument + "." + argument
         else
            query.projection  argument
         end
      execute ?  q.execute &.allocate_model : q
    end


    # get Vertices through in by edges of type via
    def in count=0, via:nil
      if count.zero?
        @bufferedin ||= nodes :in,  1, via: via
      else
        nodes :in, count, via: via   # not cached
      end
    end

    # get Vertices through out by edges of type via
    def out count=0, via:nil
      if count.zero?
        @bufferedout ||= nodes :out, 1,  via: via
      else
        nodes :out, count, via: via   # not cached
      end
    end
    #
    # get all Vertices connected by edges of type via
    def both count=0, via:nil
      if count.zero?
        @bufferedboth ||= nodes :both, 1, via: via
      else
        nodes :both, count, via: via   # not cached
      end
    end


    # get via-type-edges  through in
    def inE count=1, via:nil
      edges :in,  count, via: via
    end
    #
    # get via-type-edges  through  out
    def outE count=1, via:nil
      edges :out, count,  via: via
    end

    # get  all via-type-edges
    def bothE  count=1, via:nil
      edges :both, count, via: via
    end


	# Returns a collection of all vertices passed during the traversal
	#
	# Includes the start_vertex (start_at =0 by default)
	#
	# If the vector should not include the start_vertex, call with `start_at: 1` and increase the depth by 1
	#
	# fires a query
	#
	#    select  from  ( traverse  outE('}#{via}').in  from #{vertex}  while $depth < #{depth}   )
	#            where $depth >= #{start_at}
	#
	# If » execute: false « is specified, the traverse-statement is returned (as Arcade::Query object)
  #
  # Multiple Edges can be specifies in the via-parameter (use Array-notation)
    # e.i.
    #  traverse( :in, via: [TG::DateOf, Arcade::HasOrder], depth: 4, start_at: 1 ).map(&:w).reverse
    #
	def traverse in_or_out = :out, via: nil,  depth: 1, execute: true, start_at: 0, where: nil

			the_query = query kind: 'traverse'
      the_query.projection  in_or_out.to_s + "(" + resolve_edge_name(*via) + ")"
			the_query.where where if where.present?
			the_query.while "$depth < #{depth} " unless depth <=0
			outer_query = Query.new from: the_query, where: "$depth >= #{start_at}"
			execute ?  outer_query.execute.allocate_model :  the_query # return only the traverse part
		end

=begin
Assigns another Vertex via an EdgeClass. If specified, puts attributes on the edge.

`Vertex.assign via: Edge to: Vertex`

Returns the reloaded assigned vertex

Wrapper for
  Edge.create from: self, to: a_vertex,  some: attributes.  on: the,  edge: type }

returns the assigned vertex, thus enabling to chain vertices through

    Vertex.assign() via: E , to: VertexClass.create()).assign( via: E, ... )
or
	  (1..100).each{|n| vertex = vertex.assign(via: E2, vertex: V2.create(item: n))}
=end

  def assign vertex: nil , via: Arcade::Edge   , **attributes
    vertex = attributes[:to] if attributes.has_key? :to
    raise "vertex not provided" if vertex.nil?

    via.create from: self, to: vertex,  **attributes

    db.get vertex.rid unless vertex.is_a? Array # return the assigned vertex
  rescue IndexError => e
    db.logger.error "Edge not created, already present."
    vertex  #  return the vertex (for chaining)
  rescue ArgumentError => e
    db.logger.error "ArgumentError: #{e.message}"
    nil
  end


  def remove
    db.execute{ "delete vertex #{rid}" }
	end
=begin
Human readable representation of Vertices

Format: < Classname: Edges, Attributes >
=end
	def to_human

    in_and_out =  "{#{inE.count}->}{->#{outE.count }}, "

		#Default presentation of Arcade::Base::Model-Objects

		"<#{self.class.to_s.snake_case}[#{rid}]:"  +
      in_and_out +
      invariant_attributes.map do |attr, value|
			v= case value
				 when  Class
					 "< #{self.class.to_s.snake_case}: #{value.rid} >"
				 when Array
					 value.to_s
				 else
					 value.from_db
				 end
			"%s: %s" % [ attr, v]  unless v.nil?
		end.compact.sort.join(', ') + ">".gsub('"' , ' ')
	end


    def refresh
      # force reloading of edges and nodes
      # edges are not cached (now)
      @bufferedin, @bufferedout, @bufferedboth = nil
      super
    end
    # expose class method to instances (as private)
#    private  define_method :resolve_edge_name, &method(:resolve_edge_name)
#    private_class_method  :resolve_edge_name
end
end
