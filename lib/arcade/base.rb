module Arcade
  class Base  < Dry::Struct

    extend Arcade::Support::Sql
    # schema schema.strict    #  -- throws an error if  specified keys are missing
    transform_keys{ |x|  x[0] == '@' ? x[1..-1].to_sym : x.to_sym }
    # Types::Rid -->  only accept  #000:000,  raises an Error, if rid is not present
    attribute :rid, Types::Rid
    # maybe there are edges   ## removed in favour of instance methods
#    attribute :in?, Types::Nominal::Any
#    attribute :out?, Types::Nominal::Any
    # any not defined property goes to values
    attribute :values?, Types::Nominal::Hash


    def accepted_methods
      [ :rid, :to_human, :delete ]
    end
    #                                                                                               #
    ## ----------------------------------------- Class Methods------------------------------------ ##
    #                                                                                               #
    class << self

      # this has to be implemented on class level
      # otherwise it interfere  with attributes
      def database_name
        self.name.snake_case
      end

      def create_type
        the_class = nil   # declare as local var
        parent_present = ->(cl){ db.hierarchy.flatten.include? cl }
        e = ancestors.each
        myselfclass = e.next  # start with the actual class(self)
        loop do
          superclass = the_class  = e.next
          break if the_class.is_a? Class
        end
        begin
        loop do
          if the_class.respond_to?(:demodulize) 
            if [ 'Document','Vertex', 'Edge'].include?(the_class.demodulize)
              if  the_class == superclass  # no inheritance
                ## we have to use demodulize as the_class actually is Arcade::Vertex, ...
                unless parent_present[ to_s.snake_case ]
                  db.create_type the_class.demodulize, to_s.snake_case
                else
                  db.logger.warn "Type #{to_s.snake_case} is present, process skipped"
                end
              else
                if superclass.is_a? Class  #  maybe its a module. 
                   extended = superclass.to_s.snake_case
                 else
                   extended = superclass.superclass.to_s.snake_case
                 end
                if !parent_present[extended]
                  superclass.create_type
                end
                db.create_type the_class.demodulize, to_s.snake_case, extends:  extended
              end
              break  # stop iteration
            end
          end
          the_class = e.next  # iterate through the enumerator
        end
        # todo
        # include `created`` and `updated` properties to the aradedb-database schema if timestamps are set
        # (it works without declaring them explicitly, its thus omitted for now )
        # Integration is easy: just execute two commands
        custom_setup = db_init rescue ""
        custom_setup.each_line do |  command |
          the_command =  command[0 .. -2]  #  remove '\n'
          next if the_command == ''
        #  db.logger.info "Custom Setup:: #{the_command}"
          db.execute { the_command }
        end unless custom_setup.nil?

        rescue Arcade::RollbackError => e
          db.logger.warn e
        rescue RuntimeError => e
          db.logger.warn e
        end
      end


      def drop_type
        db.drop_type to_s.snake_case
      end

      def properties

      end



      # add timestamp attributes to the model
      #
      # updated is optional
      #
      # timestamps are included in create and update statements
      #
      def timestamps set=nil
        if set && @stamps.nil?
          @stamps = true
          attribute :created, Types::JSON::DateTime
          attribute :updated?, Types::JSON::DateTime
        end
        @stamps
      end



      ## ----------------------------------------- insert       ---------------------------------- ##
      #
      #  Adds a record to the database
      #
      #  returns the inserted record
      #
      #  Bucket and Index are supported
      #
      #  fired Database-command
      #  INSERT INTO  <type>  BUCKET<bucket> INDEX <index> [CONTENT {<attributes>}]
      #        (not supported (jet): [RETURN <expression>] [FROM <query>] )

      def insert **attributes
        db.insert type: database_name, **attributes
      end

      ## ----------------------------------------- create       ---------------------------------- ##
      #
      #  Adds a record to the database
      #
      #  returns the model dataset
      #  ( depreciated )

      def  create **attributes
        Api.begin_transaction db.database
        attributes.merge!( created: DateTime.now ) if timestamps
        record = insert **attributes
        Api.commit db.database
        record
      rescue QueryError => e
        db.logger.error "Dataset NOT created"
        db.logger.error "Provided Attributes: #{attributes.inspect}"
       #  Api.rollback db.database   --->  raises "transactgion not begun" 
      rescue  Dry::Struct::Error => e
        Api.rollback db.database
        db.logger.error "#{rid} :: Validation failed, record deleted."
        db.logger.error e.message
      end

      def count  **args
        command = "count(*)"
        query( **( { projection:  command  }.merge args  ) ).query.first[command.to_sym] rescue 0
      end

      # Lists all records of a type
      #
      # Accepts any parameter supported by Arcade::Query
      #
      # Model.all false    --> suppresses the autoload mechanism
      #
      # Example
      #
      # My::Names.all order: 'name', autoload: false
      #
      def all  a= true, autoload: true, **args
        autoload =  false if a != autoload
        query(**args).query.allocate_model( autoload )
      end

      # Lists the first record of a type or a query
      #
      # Accepts any parameter supported by Arcade::Query
      #
      # Model.first false    --> suppresses the autoload mechanism
      #
      # Example
      #
      # My::Names.first where: 'age < 50', autoload: false
      #
      def first a= true, autoload: true, **args
        autoload =  false if a != autoload
        query( **( { order: "@rid"  , limit: 1  }.merge args ) ).query.allocate_model( autoload ) &.first
      end


      # Lists the last record of a type or a query
      #
      # Accepts any parameter supported by Arcade::Query
      #
      # Model.last false    --> suppresses the autoload mechanism
      #
      # Example
      #
      # My::Names.last where: 'age > 50', autoload: false
      #
      def last  a= true, autoload: true, **args
        autoload =  false if a != autoload
        query( **( { order: {"@rid" => 'desc'} , limit: 1  }.merge args ) ).query.allocate_model( autoload )&.first
      end

      # Selects records of a type or a query
      #
      # Accepts **only** parameters to restrict the query (apart from autoload).
      #
      # Use `Model.query where: args``to use the full range of supported parameters
      #
      # Model.where false    --> suppresses the autoload mechanism
      #
      # Example
      #
      # My::Names.last where: 'age > 50', autoload: false
      #
      def where a= true, autoload: true, **args
        autoload =  false if a != autoload
         args = a if a.is_a?(String)
         ##  the result is always an array
         query( where: args ).query.allocate_model(autoload)
      end

      # Finds the first matching record providing the parameters of a `where` query
      #  Strategie.find symbol: 'Still'
      #  is equivalent to
      #  Strategie.all.find{|y| y.symbol == 'Still'
      #  }
      def find **args
        f= where(**args).first
        f= where( "#{args.keys.first} like #{args.values.first.to_or}" ) if f.nil? || f.empty?
        f
      end
      # update returns a list of updated records
      #
      # It fires a query   update <type> set <property> = <new value > upsert return after $current where  < condition >
      #
      # which returns a list of modified rid's
      #
      #  required parameter:  set:
      #                     where:
      #
      #todo refacture required parameters notification
      #
      def update **args
        if args.keys.include?(:set) && args.keys.include?(:where)
          args.merge!( updated: DateTime.now ) if timestamps
          query( **( { kind: :update }.merge args ) ).execute do |r|
            r[:"$current"] &.allocate_model(false)  #  do not autoload modelfiles
          end
        else
          raise "at least set: and where: are required to perform this operation"
        end
      end

      # update! returns the count of affected records
      #
      #  required parameter:  set:
      #                     where:
      #
      def update! **args
        if args.keys.include?(:set) && args.keys.include?(:where)
          args.merge!( updated: DateTime.now ) if timestamps
          query( **( { kind: :update! }.merge args ) ).execute{|y| y[:count] } &.first
        else
          raise "at least set: and where: are required to perform this operation"
        end
      end


      # returns a list of updated records
      def upsert **args
        set_statement = args.delete :set
        args.merge!( updated: DateTime.now ) if timestamps
        where_statement = args[:where] || args
        statement = if set_statement
                      { set: set_statement, where: where_statement }
                    else
                      { where: where_statement }
                    end
        result= query( **( { kind: :upsert  }.merge statement ) ).execute do | answer|
          z=  answer[:"$current"] &.allocate_model(false)  #  do not autoload modelfiles
          raise Arcade::LoadError "Upsert failed"   unless z.is_a?  Arcade::Base
          z  #  return record
        end
      end


      def query **args
        Arcade::Query.new( **{ from: self }.merge(args) )
      end

      # immutable support
      # to make a database type immutable add
      #  `not_permitted :update, :upsert, :delete`
      # to the model-specification
      #
      def not_permitted *m
        m.each do | def_m |
          define_method(  def_m ) do | v = nil |
          raise ArcadeImmutableError "operation not permitted", caller
        end
        end
      end

    end
    #                                                                                   #
    ## ------------------------- Instance Methods ----------------------------------- -##
    #                                                                                   #

    ## Attributes can be declared in the model file
    ##
    ## Those not covered there are stored in the `values` attribute
    ##
    ## invariant_attributes removes :rid, :in, :out, :created_at, :updated_at  and
    #  includes :values-attributes to the list of attributes


    def invariant_attributes
      result= attributes.except :rid, :in, :out, :values, :created_at,  :updated_at
      if  attributes.keys.include?(:values)
        result.merge values
      else
        result
      end
    end

    ## enables to display values keys like methods
    ##
    def method_missing method, *key
      if attributes[:values] &.keys &.include?  method
        return values.fetch(method)
      end
    end

    def query **args
      Arcade::Query.new( **{ from: rid }.merge(args) )
    end

    # to JSON  controlls the serialisation of Arcade::Base Objects for the HTTP-JSON API
    #
    # ensure, that only the rid is transmitted to the database
    #
    def to_json *args
      unless ["#0:0", "#-1:-1"].include?  rid   #  '#-1:-1' is the null-rid
        rid
      else
        invariant_attributes.merge( :'@type' =>  self.class.database_name  ).to_json
      end
    end
    def rid?
      true unless ["#0:0", "#-1:-1"].include?  rid
    end

    # enables  usage of  Base-Objects in queries
    def to_or
      if rid?
        rid
      else
        to_json
      end
    end

    def to_human


		"<#{self.class.to_s.snake_case}" + rid? ? "[#{rid}]: " : " " + invariant_attributes.map do |attr, value|
			v= case value
				 when Arcade::Base
					 "< #{self.class.to_s.snake_case}: #{value.rid} >"
				 when Array
           value.map{|x| x.to_s}
				 else
					 value.from_db
				 end
			"%s : %s" % [ attr, v]  unless v.nil?
		end.compact.sort.join(', ') + ">".gsub('"' , ' ')
    end

    alias to_s to_human

    def update **args
      Arcade::Query.new( from: rid , kind: :update, set: args).execute
      refresh
    end

    def update_list l, value
      value = if value.is_a? Arcade::Document
                value.to_json
              else
                value.to_or
              end
      if send( l ).nil? || send(l).empty?
        db.execute { "update #{rid} set  #{l} =  [#{value}]" }
      else
        db.execute { "update #{rid} set  #{l} += #{value}" }
      end
      refresh
    end

    # updates a map  property ,  actually adds the key-value pair to the property
    def update_map m, key, value
      if send( m ).nil?
        db.execute { "update #{rid} set #{m} = MAP ( #{key.to_s.to_or} , #{value.to_or} ) "  }
      else
        db.execute { "update #{rid} set #{m}.`#{key.to_s}` = #{value.to_or}" }
      end
      refresh
    end
    def delete
      response = db.execute { "delete from #{rid}" }
      true if response == [{ count: 1 }]
    end
    def == arg
     # self.attributes == arg.attributes
      self.rid == arg.rid
    end

    def refresh
      rid.load_rid
    end
  end
end
