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
    Vertex.delete fires a "delete vertex" command to the database.

    To remove all records  use  »all: true« as argument

    To remove a specific rid, use  rid: "#nn:mmm" as argument

    "where" parameter is optional

     ExtraNode.delete where: { item: 67  }  == ExtraNode.delete item: 67

=end
    def self.delete where: {} , **args
      if args[:all] == true
        where = {}
      elsif args[:rid].present?
        return db.execute { "delete vertex #{args[:rid]}" }.first["count"]
      else
        where.merge!(args) if where.is_a?(Hash)
        return 0 if where.empty?
      end
      # query returns [{count => n }]
      db.execute { "delete vertex #{database_name} #{compose_where(where)}"  } &.first[:count] rescue 0
    end

=begin
   Creates a Vertex-Instance.
   Similar to `Vertex#insert`.

   Difference is the presence of a `created` property, a timestamp set to the time and date of creation.
=end

    def self.create timestamp: true, **args
      #t= timestamp ?  ", created = Date(#{DateTime.now.to_i}) "  : ""
      t= timestamp ?  ", created = sysdate() "  : ""
      db.execute { "create VERTEX #{database_name} set #{args.map{|x,y| [x,y.to_or].join("=")}.join(', ')+t}" } &.first.allocate_model(false)
    end


## get adjacent nodes based on a query on the actual model


    def self.nodes in_or_out = :both, via: nil ,  **args

      s =  Query.new from: self
      s.nodes in_or_out, via: via, **args
      s.query.select_result
    end


    #                                                                                               #
    ## ---------------------------------   Instance    Methods   --------------------------------- ##
    #
    #  We need expand as fallback if a vertex, which is stored as link is automatically loaded
    #
      def expand
        self
      end
    # Supports where:  -->  Strategie.first nodes  where: {size: 10}
    # "select  both()[ size = 10  ]  from #113:8 "
    def nodes in_or_out=:both, depth= 1, via: nil , execute: true, **args
      s =  Query.new from: rid
      s.nodes in_or_out, via: via, **args
      if execute
         s.query.select_result
       else
         s  #  just return the query
       end
    end

    # Supports where: { where condition for edges }
    def edges in_or_out = :both, depth= 1, via: nil , execute: true, **args
      in_or_out = in_or_out.to_s + "E"
      nodes in_or_out, depth, via: via , execute: execute, **args
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
      nodes :inE,  count, via: via
    end
    #
    # get via-type-edges  through  out
    def outE count=1, via:nil
      nodes :outE, count,  via: via
    end

    # get  all via-type-edges
    def bothE  count=1, via:nil
      nodes :bothE, count, via: via
    end


	# Returns a collection of all vertices passed during the traversal
	#
	# Includes the start_vertex (start_at =0 by default)
	#
	# If the vector should not include the start_vertex, call with `start_at:1` and increase the depth by 1
	#
	# fires a query
	#
	#    select  from  ( traverse  outE('}#{via}').in  from #{vertex}  while $depth < #{depth}   )
	#            where $depth >= #{start_at}
	#
	# If » excecute: false « is specified, the traverse-statement is returned (as Arcade::Query object)
	def traverse in_or_out = :out, via: nil,  depth: 1, execute: true, start_at: 0, where: nil

#			edges = detect_edges( in_or_out, via, expand: false)
			the_query = query kind: 'traverse'
      the_query.projection  in_or_out.to_s + "(" + resolve_edge_name(via) + ")"
			the_query.where where if where.present?
			the_query.while "$depth < #{depth} " unless depth <=0
#			edges.each{ |ec| the_query.nodes in_or_out, via: ec, expand: false }
			outer_query = Query.new from: the_query, where: "$depth >= #{start_at}"
			if execute
        outer_query.execute.allocate_model
				else
		#			the_query.from self  #  complete the query by assigning self
					the_query            #  returns the OrientQuery  -traverse object
				end
		end



=begin
Assigns another Vertex via an EdgeClass. If specified, puts attributes on the edge.

Returns the reloaded assigned vertex

Wrapper for
  Edge.create in: self, out: a_vertex,  some: attributes.  on: the,  edge: type }

returns the assigned vertex, thus enabling to chain vertices through

    Vertex.assign() via: E , vertex: VertexClass.create()).assign( via: E, ... )
or
	  (1..100).each{|n| vertex = vertex.assign(via: E2, vertex: V2.create(item: n))}
=end

  def assign vertex: , via:   , **attributes

    via.create from: self, to: vertex,  **attributes

    db.get vertex.rid  # return the assigned vertex
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

    in_and_out = -> { "{#{self.in.count}->}{->#{self.out.count }}, " }

		#Default presentation of Arcade::Base::Model-Objects

		"<#{self.class.to_s.snake_case}[#{rid}]: "  +
      in_and_out[] +
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
