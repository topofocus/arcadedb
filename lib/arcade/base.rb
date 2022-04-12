module Arcade
  class Base  < Dry::Struct

    extend Arcade::Support::Sql
    # schema schema.strict    #  -- throws an error if  specified keys are missing
    transform_keys{ |x|  x[0] == '@' ? x[1..-1].to_sym : x.to_sym }
    # only accept  #000:000,  raises an Error, if rid is not present
    attribute :rid, Types::Rid
    # maybe there are edges
    attribute :in?, Types::Nominal::Any
    attribute :out?, Types::Nominal::Any

    class << self

      # this has to be implemented on class level
      # otherwise it interfere  with attributes
      def database_name
        self.name.snake_case
      end

      def insert **attributes
        db.execute { "insert into #{database_name} CONTENT #{attributes.to_json}" }.first
      end

      alias create insert


      def count **args
        command = "count(*)"
      #  db.query( " select #{command} from #{database_name}" ).first[command] rescue 0
        query( **( { projection:  'COUNT(*)'  }.merge args  ) ).execute(reduce: true){|x|  x["COUNT(*)"]}
      end

      def all
        db.query "select from #{database_name}"
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
            query( **( { kind: :update }.merge args ) ).execute.map{|r| r["$current"].load_rid }
        else
          raise "at least set: and where: are required to perform this operation"
        end
      end

      # update! returns the count of affected recrds
      #
      #  required parameter:  set:
      #                     where:
      #
      def update! **args
        if args.keys.include?(:set) && args.keys.include?(:where)
            query( **( { kind: :update! }.merge args ) ).execute.first["count"]
        else
          raise "at least set: and where: are required to perform this operation"
        end
      end

      # returns a list of updated records
      def upsert **args
        if args.keys.include?(:set) && args.keys.include?(:where)
          result= query( **( { kind: :upsert }.merge args ) ).execute.map{|r| r["$current"].load_rid }
        else
          raise "at least set: and where: are required to perform this operation"
        end
      end

      def query **args
        Arcade::Query.new( **{ from: self }.merge(args) )
      end

    end
    #                                                                                   #
    ## ------------------------- Instance Methods ----------------------------------- -##
    #                                                                                   #
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
