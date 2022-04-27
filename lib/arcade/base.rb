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
        parent_present = ->(cl){ db.hierarchy.flatten.include? cl }
        e = ancestors.each
        myselfclass = e.next  # start with the actual class(self)
        superclass = the_class  = e.next
        loop do
          if ['Document','Vertex', 'Edge'].include? the_class.demodulize
            if  the_class == superclass  # no inheritance
              ## we have to use demodulise as the_class actually is Arcade::Vertex, ...
              db.create_type the_class.demodulize, to_s.snake_case
            else
              extended = superclass.to_s.snake_case
              if !parent_present[extended]
                superclass.create_type
              end
              db.create_type the_class.demodulize, to_s.snake_case, extends:  extended
            end
            break  # stop iteration
          end
          the_class = e.next  # iterate through the enumerator
        end
        custom_setup = db_init rescue ""
        custom_setup.each_line do |  command |
          the_command =  command[0 .. -2]  #  remove '\n'
          next if the_command == ''
        #  db.logger.info "Custom Setup:: #{the_command}"
          db.execute { the_command }
        end unless custom_setup.nil?

      end
      def properties

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
        record = insert **attributes
        Api.commit db.database
        record
      rescue RuntimeError => e
        db.logger.error "Dataset NOT created"
        db.logger.error "Provided Attributes: #{attributes.inspect}"
        Api.rollback db.database
      rescue  Dry::Struct::Error => e
        db.delete rid
        db.logger.error "#{rid} :: Validation failed, record deleted."
        db.logger.error e.message
        Api.rollback db.database
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
        query( **( { order: "@rid"  , limit: 1  }.merge args ) ).query.allocate_model( autoload ).first
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
        query( **( { order: {"@rid" => 'desc'} , limit: 1  }.merge args ) ).query.allocate_model( autoload ).first
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
         query( where: args ).query.allocate_model( autoload )
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
            query( **( { kind: :update }.merge args ) ).execute{|r| r[:"$current"].load_rid }
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
          query( **( { kind: :update! }.merge args ) ).execute{|y| y[:count] } &.first
        else
          raise "at least set: and where: are required to perform this operation"
        end
      end

      # returns a list of updated records
      def upsert **args
        set_statement = args.delete :set
        where_statement = args[:where] || args
        statement = if set_statement
                      { set: set_statement, where: where_statement }
                    else
                      { where: where_statement }
                    end
        result= query( **( { kind: :upsert  }.merge statement ) ).execute do | answer|
puts           answer.class
puts answer
           z=  answer[:"$current"] &.load_rid(false)   #  do not autoload modelfiles
           error "Upsert failed", :load  unless z.is_a?  Arcade::Base
           z  #  return record
        end
      end

      def query **args
        Arcade::Query.new( **{ from: self }.merge(args) )
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
      rid
    end
    def rid?
      true
    end
    def to_human


		"<#{self.class.to_s.snake_case}[#{rid}]: " + invariant_attributes.map do |attr, value|
			v= case value
				 when Arcade::Base
					 "< #{self.class.to_s.snake_case}: #{value.rid} >"
				 when Array
           value.map{|x| x.to_s}
#					 value.rrid #.to_human #.map(&:to_human).join("::")
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

    def == arg
      self.attributes == arg.attributes
    end

    def refresh
      rid.load_rid
    end
  end
end
