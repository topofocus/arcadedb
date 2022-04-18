module Arcade
  class Base  < Dry::Struct

    extend Arcade::Support::Sql
    # schema schema.strict    #  -- throws an error if  specified keys are missing
#    transform_keys{ |x|  x[0] == '@' ? x[1..-1].to_sym : x.to_sym }
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

      def create_type name
        e = ancestors.each
        superclass = e.next  # the actual class
        the_class =  superclass
        loop do
          if ['Document','Vertex', 'Edge'].include? the_class.demodulize
#            extends =  (the_class != superclass) ? { "EXTENDS #{superclass.to_s.snake_case} " : ""
#            db.execute { "create  #{the_class.demodulize} TYPE  #{name} #{extends} " }
           if  the_class == superclass
            db.create_type the_class.demodulize, name
           else
            db.create_type the_class.demodulize, name, extends:  superclass.to_s.snake_case
          end
            break
          end
          the_class = e.next  # the actual class
        end
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
#        Api.begin_transaction db.database
         insert **attributes
#        Api.commit db.database
      rescue RuntimeError => e
        db.logger.error "Dataset NOT created"
        db.logger.error "Provided Attributes: #{attributes.inspect}"
#        Api.rollback db.database
      rescue  Dry::Struct::Error => e
        db.delete rid
        db.logger.error "#{rid} :: Validation failed, record deleted."
        db.logger.error e.message
 #       Api.rollback db.database
      end

      def count **args
        command = "count(*)"
        query( **( { projection:  command  }.merge args  ) ).execute(reduce: true){|x|  x[command.to_sym]}
      end

      def all
        query.execute
      end

      def first **args
         query( **( { order: "@rid" , limit: 1  }.merge args ) ).execute(reduce: true)
      end


      def last **args
         query( **( { order: {"@rid" => 'desc'} , limit: 1  }.merge args ) ).execute(reduce: true)
      end

      def where *args
         query( where: args ).execute
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
            query( **( { kind: :update }.merge args ) ).execute.map{|r| r[:"$current"].load_rid }
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
            query( **( { kind: :update! }.merge args ) ).execute.first[:count]
        else
          raise "at least set: and where: are required to perform this operation"
        end
      end

      # returns a list of updated records
      def upsert **args
        if args.keys.include?(:set) && args.keys.include?(:where)
          result= query( **( { kind: :upsert }.merge args ) ).execute.map{|r| r[:"$current"].load_rid }
        else
          raise "at least set: and where: are required to perform this operation"
        end
      end

      def query **args
        Arcade::Query.new( **{ from: self }.merge(args) )
      end

      def allocate_record **att
        att[:rid] = att.delete :"@rid"   
        att[:in] = att.delete(:"@in") #if att[:"@in"].rid?
        att[:out] = att.delete(:"@out") #if att[:"@out"].rid?
        att =  att.except :"@type", :"@cat", :"@rid", :"@in", :"@out"                   # remove internal attributes
        new = self.new   att                                                            # create a prototype
        v =  att.except  *new.attributes.keys                                           # get attributes not included in prototype
       # new=  self.new new.attributes.merge( values: v ) unless v.empty?               #
        new = new.new( values: v ) unless v.empty?                                      # Include those attributes in values attribute
        new                                                                             # return the allocated record
      end

      private :allocate_record
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
       attributes.except :rid, :in, :out
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

 
    def rid?
      true
    end
    def to_human


		"<#{self.class.to_s.snake_case}[#{rid}]: " + invariant_attributes.map do |attr, value|
			v= case value
				 when Arcade::Base
					 "< #{self.class.to_s.snake_case}: #{value.rid} >"
				 when Array
					 value.to_s
#					 value.rrid #.to_human #.map(&:to_human).join("::")
				 else
					 value.from_db
				 end
			"%s : %s" % [ attr, v]  unless v.nil?
		end.compact.sort.join(', ') + ">".gsub('"' , ' ')
    end

    alias to_s to_human 

    def update **args
        rid.update **args
      end
      def == arg
        self.attributes == arg.attributes
      end

      def refresh
        rid.load_rid
      end
  end
end
