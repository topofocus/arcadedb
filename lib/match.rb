#require 'active_support/inflector'

module Arcade
	######################## MatchConnection ###############################

	MatchAttributes = Struct.new(:edge, :direction, :as, :count, :where, :while, :max_depth , :depth_alias, :path_alias, :optional )

	# where and while can be composed incremental
	# direction, as, connect and edge cannot be changed after initialisation
  class MatchConnection
    include Support::Sql

    def initialize edge= nil, direction: :both, as: nil, count: 1, **args

      the_edge = edge.is_a?( Class ) ?  edge.ref_name : edge.to_s   unless edge.nil? || edge == E
			@q =  MatchAttributes.new  the_edge ,  # class
								direction, #		  may be :both, :in, :out
								as,				 #      a string
								count,     #      a number 
								args[:where],
								args[:while],
								args[:max_depth],
								args[:depth_alias],      # not implemented
								args[:path_alias],       # not implemented
								args[:optional]          # not implemented
    end

    def direction= dir
      @q[:direction] =  dir
    end


		def direction
			fillup =  @q[:edge].present? ? @q[:edge] : ''
			case @q[:direction]
			when :both
				".both(#{fillup})"
			when :in
				".in(#{fillup})"
			when :out
				".out(#{fillup})"
      when :both_vertex, :bothV
				".bothV()"
			when :out_vertex, :outV
				".outV()"
			when :in_vertex, :inV
				".inV()"
     when :both_edge, :bothE
			 ".bothE(#{fillup})"
			when :out_edge, :outE
				".outE(#{fillup})"
			when :in_edge, :outE
				".inE(#{fillup})"
			end

		end

		def count c=nil
			if c
				@q[:count] = c
			else
				@q[:count]
			end
		end

		def max_depth d=nil
			if d.nil?
				@q[:max_depth].present? ? "maxDepth: #{@q[:max_depth] }" : nil
			else
				@q[:max_depth] = d
			end
		end
		def edge
			@q[:edge]
		end

		def compose
				where_statement =( where.nil? || where.size <5 ) ? nil : "where: ( #{ generate_sql_list( @q[:where] ) })"
				while_statement =( while_s.nil? || while_s.size <5) ? nil : "while: ( #{ generate_sql_list( @q[:while] )})"

				ministatement = "{"+ [ as, where_statement, while_statement, max_depth].compact.join(', ') + "}"
				ministatement = "" if ministatement=="{}"

     (1 .. count).map{|x| direction }.join("") + ministatement

    end
		alias :to_s :compose

  end  # class


	######################## MatchStatement ################################

	MatchSAttributes = Struct.new(:match_class, :as, :where )
  class MatchStatement
    include Support
    def initialize match_class, as: 0,  **args
			reduce_class = ->(c){ c.is_a?(Class) ? c.ref_name : c.to_s }

			@q =  MatchSAttributes.new( reduce_class[match_class],  # class
								as.respond_to?(:zero?) && as.zero? ?  reduce_class[match_class].pluralize : as	,
								args[ :where ])

			@query_stack = [ self ]
		end

		def match_alias
			"as: #{@q[:as]}"
		end



		# used for the first compose-statement of a compose-query
		def compose_simple
				where_statement = where.is_a?(String) && where.size <3 ?  nil :  "where: ( #{ generate_sql_list( @q[:where] ) })"
			'{'+ [ "class: #{@q[:match_class]}",  as , where_statement].compact.join(', ') + '}'
		end


		def << connection
			@query_stack << connection
			self  # return MatchStatement
		end
		#
		def compile &b
     "match " + @query_stack.map( &:to_s ).join + return_statement( &b )
		end


		# executes the standard-case.
		# returns
		#  * as: :hash   : an array of  hashes
		#  * as: :array  : an array of hash-values
		#  * as  :flatten: a simple array of hash-values
		#
		# The optional block is used to customize the output.
		# All previously defiend »as«-Statements are provided though the control variable.
		#
		# Background
		# A match query   "Match {class aaa, as: 'aa'} return aa "
		#
		# returns [ aa: { result of the query, a Vertex or a value-item  }, aa: {}...}, ...] ]
		# (The standard case)
		#
		# A match query   "Match {class aaa, as: 'aa'} return aa.name "
		# returns [ aa.name: { name  }, aa.name: { name }., ...] ]
		#
		# Now, execute( as: :flatten){ "aa.name" }  returns
		#  [name1, name2 ,. ...]
		#
		#
		# Return statements  (examples from https://orientdb.org/docs/3.0.x/sql/SQL-Match.html)
		#  "person.name as name, friendship.since as since, friend.name as friend"
		#
		#  " person.name + \" is a friend of \" + friend.name as friends"
		#
		#  "$matches"
		#  "$elements"
		#  "$paths"
		#  "$pathElements"
		#
		#
		def execute as: :hash, &b
			r = V.db.execute{ compile &b }
			case as
			when :hash
				r
			when :array
			 r.map{|y| y.values}
			when :flatten
			 r.map{|y| y.values}.orient_flatten
			else
				raise ArgumentError, "Specify parameter «as:» with :hash, :array, :flatten"
		 end
		end
#		def compose
#
#			'{'+ [ "class: #{@q[:match_class]}",
#					"as: #{@as}" , where, while_s,
#						@maxdepth >0 ? "maxdepth: #{maxdepth}": nil  ].compact.join(', ')+'}'
#		end

		alias :to_s :compose_simple


##  return_statement
		#
		# summarizes defined as-statements ready to be included as last parameter
		# in the match-statement-stack
		#
		# They can be modified through a block.
		#
		# i.e
		#
		# t= TestQuery.match(  where: {a: 9, b: 's'}, as: nil ) << E.connect("<-", as: :test)
		# t.return_statement{|y| "#{y.last}.name"}
		#
		# =>> " return  test.name"
		#
		#return_statement is always called through compile
		#
		# t.compile{|y| "#{y.last}.name"}

    private
		def return_statement
			resolve_as = ->{ @query_stack.map{|s| s.as.split(':').last unless s.as.nil? }.compact }
			" return " + statement = if block_given?
										a= yield resolve_as[]
										a.is_a?(Array) ? a.join(', ') :  a
									else
										resolve_as[].join(', ')
									end
		end
	end  # class

end # module
