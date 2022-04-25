module Arcade
  class Vertex  < Base

#    include Arcade::Support::Sql
    
    attribute :in?, Types::Nominal::Any
    attribute :out?, Types::Nominal::Any
    #                                                                                               #
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
    List

    1. call without any parameter:  list all edges present
    2. call with :in or :out     :  list any incoming or outgoing edges
    3. call with /regexp/, Class, symbol or string: restrict to this edges, including inheritence
       If a pattern, symbol string or class is provided, the default is to list outgoing edges

      :call-seq:
      edges in_or_out, pattern 
=end

## get adjacent nodes based on a query on the actual model


    def self.nodes in_or_out = :both, via: nil ,  **args

       io =  in_or_out.to_s + "(" + resolve_edge_name(via) + ")"
        search_query =  Query.new from: self, **args
        nodes_query  =  Query.new from: search_query, projection: io
        puts "nodes: #{nodes_query.to_s} "
        nodes_query.execute.allocate_model
    end


    #                                                                                               #
    ## ---------------------------------   Instance    Methods   --------------------------------- ##
    #                                                                                               #

    def nodes in_or_out = :both, depth= 1, via: nil , execute: true
      io =  in_or_out.to_s+ "(" + resolve_edge_name(via) + ")"
       if execute
         query( projection: io ).execute &.first &.values &.allocate_model &.flatten
       else
         query(projection: io )
       end
    end

    def edges in_or_out = :both, depth= 1, via: nil , execute: true
      in_or_out = :both unless [:in, :out,].include? in_or_out
      in_or_out = in_or_out.to_s + "E"
      nodes in_or_out, depth, via: via , execute: execute
    end


    # get Vertices through in by edges of type via
    def in count=1, via:nil
      nodes :in,  count, via: via
    end

    # get Vertices through out by edges of type via
    def out count=1, via:nil
      nodes :out, count,  via: via
    end
    #
    # get all Vertices connected by edges of type via
    def both count=1, via:nil
      nodes :both, count, via: via
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

Wrapper for
  Edge.create in: self, out: a_vertex, attributes: { some_attributes on the edge }

returns the assigned vertex, thus enabling to chain vertices through

    Vertex.assign() via: E , vertex: VertexClass.create()).assign( via: E, ... )
or
	  (1..100).each{|n| vertex = vertex.assign(via: E2, vertex: V2.create(item: n))}
=end

  def assign vertex: , via:   , attributes: {}

    via.create from: self, to: vertex, set: attributes

		vertex
  rescue ArgumentError => e
    puts e.message
    nil
  end


 # def remove
 #   db.delete_vertex self
#	end
=begin
Human readable representation of Vertices

Format: < Classname: Edges, Attributes >
=end
	def to_human


		#Default presentation of Arcade::Base::Model-Objects

		"<#{self.class.to_s.snake_case}[#{rid}]: "  + invariant_attributes.map do |attr, value|
			v= case value
				 when  Class
					 "< #{self.class.to_s.snake_case}: #{value.rid} >"
				 when Array
					 value.to_s
#					 value.rrid #.to_human #.map(&:to_human).join("::")
				 else
					 value.from_db
				 end
			"%s: %s" % [ attr, v]  unless v.nil?
		end.compact.sort.join(', ') + ">".gsub('"' , ' ')
	end

#
#		def edge_name.present? name
#			# if a class is provided, match for the ref_name only
#      present_edges = -> { db.hierarchy( type: 'edge' ).flatten }
#      case name
#         when Class
#            name.database_name
#         when Regexp
#            present_edges.grep name
#         when String
#           present_edges.find{|x| x == x.name }
#         when Symbol
#           present_edges.find{|x| x == x.name.to_s }
#         else
#           ""
#         end
#    end
    #
    ## helper method
    def self.resolve_edge_name edge_name
      case  edge_name
                    when nil
                      ""
                    when Class
                      edge_name.database_name
                    when String
                     edge_name 
                    end
    end

    # expose class method to instances (as private)
    private  define_method :resolve_edge_name, &method(:resolve_edge_name)
    private_class_method  :resolve_edge_name
end
end
