#require ' active_support/inflector'

module Arcade

	######################## Query ###################################

	QueryAttributes =  Struct.new( :kind,  :projection, :where, :let, :order, :while, :misc,
																:class, :return,  :aliases, :database,
																:set, :remove, :group, :skip, :limit, :unwind,  :map )

	class Query
    include Support::Sql
    include Support::Model


#
    def initialize  **args
			@q =  QueryAttributes.new args[:kind] ||	'select' ,
								[], #		 :projection 
								[], # :where ,
								[], # :let ,
								[], # :order,
								[], # :while,
								[] , # misc
								'',  # class
								'',  #  return
								[],   # aliases
								'',  # database
								[],   #set,
								[]  # remove
			  args.each{|k,v| send k, v}
				@fill = block_given? ?   yield  : 'and'
		end

=begin
  where: "r > 9"                          --> where r > 9
  where: {a: 9, b: 's'}                   --> where a = 9 and b = 's'
  where:[{ a: 2} , 'b > 3',{ c: 'ufz' }]  --> where a = 2 and b > 3 and c = 'ufz'
=end
		def method_missing method, *arg, &b   # :nodoc:
			if method ==:while || method=='while'
				while_s arg.first
			else
				@q[:misc] << method.to_s <<  generate_sql_list(arg)
			end
			self
    end

		def misc   # :nodoc:
			@q[:misc].join(' ') unless @q[:misc].empty?
		end

    def subquery  # :nodoc:
      nil
    end

		def kind value=nil
			if value.present?
				@q[:kind] = value
				self
			else
			@q[:kind]
			end
		end
=begin
  Output the compiled query
  Parameter: destination (rest, batch )
  If the query is submitted via the REST-Interface (as get-command), the limit parameter is extracted.
=end

		def compose(destination: :batch)
			if kind.to_sym == :update
				return_statement = "return after " + ( @q[:aliases].empty? ?  "$current" : @q[:aliases].first.to_s)
				[ 'update', target, set, remove, return_statement, where ].compact.join(' ')
      elsif kind.to_sym == :"update_map"
        [ "update", target, map, where, misc ].compact.join(' ')
			elsif kind.to_sym == :update!
				[ 'update', target, set, where, misc ].compact.join(' ')
#			elsif kind.to_sym == :create                                             # relict of orientdb
#				[ "CREATE VERTEX", target, set ].compact.join(' ')
			#	[ kind, target, set,  return_statement ,where,  limit, misc ].compact.join(' ')
			elsif kind.to_sym == :upsert
        set(  generate_sql_list( @q[:where] ){ @fill || 'and' } ) if set.nil?
				return_statement = "return after " + ( @q[:aliases].empty? ?  "$current" : @q[:aliases].first.to_s)
				[ "update", target, set,"upsert", return_statement, where, limit, misc  ].compact.join(' ')
				#[ kind,  where, return_statement ].compact.join(' ')
			elsif destination == :rest
				[ kind, projection, from, let, where, subquery,  misc, order, group_by, unwind, skip].compact.join(' ')
			else
				[ kind, projection, from, let, where, subquery,  while_s,  misc, order, group_by, limit, unwind, skip].compact.join(' ')
			end
		end
		alias :to_s :compose


		def to_or
			compose.to_or
		end

		def target arg =  nil
			if arg.present?
				@q[:database] =  arg
				self # return query-object
			elsif @q[:database].present?
				the_argument =  @q[:database]
				case @q[:database]
									when Arcade::Base   # a single record
										the_argument.rid
									when self.class	      # result of a query
										' ( '+ the_argument.compose + ' ) '
									when Class
										the_argument.database_name
									else
										if the_argument.to_s.rid?	  # a string with "#ab:cd"
											the_argument
										else		  # a database-class-name
											the_argument.to_s
										end
									end
			else
				raise "cannot complete until a target is specified"
			end
		end

=begin
	from can either be a Databaseclass to operate on or a Subquery providing data to query further
=end
		def from arg = nil
			if arg.present?
				@q[:database] =  arg
				self # return query-object
			elsif  @q[:database].present? # read from
				"from #{ target }"
			end
		end


		def order  value = nil
			if value.present?
				@q[:order] << value
				self
			elsif @q[:order].present?

				"order by " << @q[:order].compact.flatten.map do |o|
					case o
					when String, Symbol, Array
						o.to_s
					else
						o.map{|x,y| "#{x} #{y}"}.join(" ")
					end  # case
				end.join(', ')
			else
				''
			end # unless
		end	  # def


    def database_class            # :nodoc:
      @q[:database]
    end

    def database_class= arg   # :nodoc:
      @q[:database] = arg
    end

		def distinct d
			@q[:projection] << "distinct " +  generate_sql_list( d ){ ' as ' }
			self
		end

class << self
		def mk_simple_setter *m
			m.each do |def_m|
				define_method( def_m ) do | value=nil |
						if value.present?
							@q[def_m]  = value
							self
						elsif @q[def_m].present?
						 "#{def_m.to_s} #{generate_sql_list(@q[def_m]){' ,'}}"
						end
				end
			end
		end
		def mk_std_setter *m
			m.each do |def_m|
				define_method( def_m  ) do | value = nil |
					if value.present?
						@q[def_m] << case value
													when String
														value
													when ::Hash
														value.map{|k,v| "#{k} = #{v.to_or}"}.join(", ")
													else
														raise "Only String or Hash allowed in  #{def_m} statement"
													end
						self
					elsif @q[def_m].present?
						"#{def_m.to_s} #{@q[def_m].join(',')}"
					end # branch
				end     # def_method
			end  # each
		end  #  def
end # class << self
		mk_simple_setter :limit, :skip, :unwind
		mk_std_setter :set, :remove

      def while_s  value=nil     # :nodoc:
        if value.present?
          @q[:while] << value
          self
        elsif @q[:while].present?
          "while #{ generate_sql_list( @q[:while] ) }"
        end
      end
      def where  value=nil     # :nodoc:
        if value.present?
          if value.is_a?( Hash ) && value.size >1
            value.each {| a, b | where( {a => b} ) }
          else
            @q[:where] <<  value
          end
          self
        elsif @q[:where].present?
          "where #{ generate_sql_list( @q[:where] ){ @fill || 'and' } }"
        end
      end

      def as a=nil
        if a
          @q[:as] = a   # subsequent calls overwrite older entries
        else
          if @q[:as].blank?
            nil
          else
            "as: #{ @q[:as] }"
          end
        end
      end

      # update_map  -  update an embedded map
      def map  value=nil
         if value.present?
           @q[:map] = value
           self
         elsif @q[:map].present?
           # only one pair is supported
           "set #{@q[:map].keys.first} = #{@q[:map].values.first.to_or}"
         end
      end
      def let       value = nil
        if value.present?
          @q[:let] << value
          self
        elsif @q[:let].present?
          "let " << @q[:let].map do |s|
            case s
            when String
              s
            when ::Hash
              s.map do |x,y|
                # if the symbol: value notation of Hash is used, add "$" to the key
                x =  "$#{x.to_s}"  unless x.is_a?(String) && x[0] == "$"
                "#{x} = #{ case y
                when self.class
                  "(#{y.compose})"
                else
                  y.to_db
                end }"
              end
            end
          end.join(', ')
        end
      end
      #
		def projection value= nil  # :nodoc:
			if value.present?
				@q[:projection] << value
				self
			elsif  @q[:projection].present?
				@q[:projection].compact.map do | s |
					case s
					when ::Array
						s.join(', ')
					when String, Symbol
						s.to_s
					when ::Hash
						s.map{ |x,y| "#{x} as #{y}"}.join( ', ')
					end
				end.join( ', ' )
			end
		end

	  def group value = nil
			if value.present?
        @q[:group] << value
			self
      elsif @q[:group].present?
        "group by #{@q[:group].join(', ')}"
			end
    end

		alias order_by order
		alias group_by group

		def get_limit  # :nodoc:
      @q[:limit].nil? ? -1 : @q[:limit].to_i
    end

		def expand item
			@q[:projection] =[ " expand ( #{item.to_s} )" ]
			self
    end

		# connects by adding {in_or_out}('edgeClass')
		def connect_with in_or_out, via: nil
			 argument = " #{in_or_out}(#{via.to_or if via.present?})"
		end
		# adds a connection
		#  in_or_out:  :out --->  outE('edgeClass').in[where-condition]
		#              :in  --->  inE('edgeClass').out[where-condition]

		def nodes in_or_out = :out, via: nil, where: nil, expand:  false

			 condition = where.present? ?  "[ #{generate_sql_list(where)} ]" : ""
       via = resolve_edge_name(via) unless via.nil?

       start =  if in_or_out.is_a? Symbol
                  in_or_out.to_s
                elsif in_or_out.is_a? String
                  in_or_out
								else
									"both"
								end
			 argument = " #{start}(#{via})#{condition} "

			 if expand.present?
				 send :expand, argument
			 else
				 @q[:projection]  << argument
			 end
			 self
		end


    def query
       db.query compose
    end

		# returns nil if the query was not sucessfully executed
		def execute(reduce: false, autoload: true )
#      unless projection.nil?    || projection.empty?
      result = db.execute { compose }
			return nil unless result.is_a?(Array)
			block_given?  ? result.map{|x| yield x }  : result
#			return  result.first if reduce && result.size == 1
      ## case  select count(*) from  ...  --> [{ :count => n }]   projection is set
      ## case update ... after $current   --> [{ :$current => n}] projection is not set, but result is an integer
      #  separate key from  values and get model-files
#      if  !@q[:projection].empty?  && result.first.is_a?(Hash)  &&  result.first.values.is_a?( Array ) 
#        if reduce
#          result.first.values.map{|x| allocate_model x, autoload}
#        else
#          result.map{|_,m| allocate_model m, autoload }
#        end
#     eloe
 #      result.map{|y| allocate_model y, autoload }
 #     end
			## standard case: return Array
			#result.arcade_flatten
		end
:protected
		def resolve_target
			if @q[:database].is_a? Arcade::Query
				@q[:database].resolve_target
			else
				@q[:database]
			end
		end

	#	end
	end # class


end # module
