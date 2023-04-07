module Arcade
  ##
  # Implements the Database-Adapter
  #
  #  currently, only attributes of type String are supported
  #
  #  {Database-instance}.database points to the connected Aradedb-database
  #  DB.hi
  #
  ##
  class Database
    include Logging
    extend Dry::Core::ClassAttributes
    include Support::Model                          #  provides  allocate_model

    defines :namespace
    defines :environment

    def initialize  environment=:development
      self.class.configure_logger( Config.logger ) 
      @connection =  connect environment
      if self.class.environment.nil?    # class attribute is set on the first call
                                        # further instances of Database share the same environment
        self.class.environment  environment
      end
      self.class.namespace  Object.const_get( Config.namespace )
    end

    def database
      @database ||= Config.database[self.class.environment]
    end

    # ------------  types ------------...
    # returns an Array of type-attributes
    # [{:name=>"Account", :type=>"document"},
    # {:name=>"test", :type=>"vertex"},
    # {:name=>"test1", :type=>"vertex"},
    # {:parentTypes=>["test1"], :name=>"test2", :type=>"vertex"}]
    #
    def types refresh=false
      #  uses API
      if $types.nil? || refresh
       $types = Api.query(database, "select from schema:types"   )
                   .map{ |x| x.transform_keys &:to_sym     }   #  symbolize keys
                   .map{ |y| y.delete_if{|_,b,| b.empty? } }   #  eliminate  empty entries
      end
      $types

    end

    def indexes
      DB.types.find{|x| x.key? :indexes }[:indexes]
    end

    # ------------ hierarchy -------------
    #  returns an Array of types
    #
    #  each  entry is an Array
    #  => [["test"], ["test1", "test2"]]   (using the example above)
    #
    #  Parameter:  type --  one of  'vertex', 'document', 'edge'
    def hierarchy type: 'vertex'
      #  uses API
      # gets all types depending  on the parent-type
      pt = ->( s ) { types.find_all{ |x| x[:parentTypes] &.include?(s) }.map{ |v| v[:name] } }
      # takes an array of base-types. gets recursivly all childs
      child_types = -> (base_types) do
        base_types.map do | bt |
          if pt[ bt ].empty?
            [ bt ]
          else
            [bt, child_types[ pt[ bt  ]  ] ].flatten
          end
        end
      end

      # gets child-types  for all   base-types
      child_types[ types.find_all{ |x| !x[:parentTypes]  && x[:type] == type.to_s }.map{ |v| v[:name] } ]

    end


    # ------------ create type -----------
    #  returns an Array
    #  Example:  > create_type :vertex, :my_vertex
    #           => [{"typeName"=>"my_vertex", "operation"=>"create vertex type"}]
    #
    #  takes additional arguments:  extends: '<a supertype>'  (for inheritance)
    #                               bucket:  <a list of  bucket-id's >
    #                               buckets:  <how many bukets to assign>
    #
    #  additional arguments are just added to the command
    #
    # its aliased as `create_class`
    #
    def create_type kind, type, **args

      exe = -> do
        case kind.to_s.downcase
        when /^v/
          "create vertex type #{type} "
        when /^d/
          "create document type #{type} "
        when /^e/
          "create edge type #{type} "
        end.concat( args.map{|x,y| "#{x} #{y} "}.join)
      end
      db= Api.execute database, &exe
      types( true )  # update cached schema
      db

    rescue Arcade::QueryError
      Arcade::Database.logger.warn "Database type #{type} already present"
    end

    alias create_class create_type

    # ------------ drop type  -----------
    #  delete any record prior to the attempt to drop a type.
    #  The `unsafe` option is nit implemented.
    def drop_type  type
      Api.execute database, "drop type #{type} if exists"
    end

    # ------------ create  -----------
    # returns an rid of the successfully  created vertex or document
    #
    #  Parameter:  name of the vertex or document type
    #              Hash of attributes
    #
    #  Example:   > DB.create :my_vertex, a: 14, name: "Hugo"
    #             => "#177:0"
    #
    def create type, **params
      #  uses API
      Api.create_document database, type,  **params
    end

    def insert  **params

      content_params = params.except( :type, :bucket, :index, :from, :return )
      target_params = params.slice( :type, :bucket, :index )
      if  target_params.empty?
        logger.error "Could not insert: target mising (type:, bucket:, index:)"
      elsif content_params.empty?
        logger.error "Nothing to Insert"
      else
        content =  "CONTENT #{ content_params.to_json }"
        target =  target_params.map{|y,z|  y==:type ?  z : "#{y.to_s} #{ z } "}.join
        Api.execute( database, "INSERT INTO #{target} #{content} ") &.first.allocate_model(false)
      end
    end

    # ------------------------------  get        ------------------------------------------------------ #
    # Get fetches the record associated with the rid given as parameter.
    #
    # The rid is accepted as
    #   DB.get "#123:123",   DB.get "123:123"  or DB.get 123, 123
    #
    #  Links are autoloaded  (can be suppressed by the optional Block (false))
    #
    # puts DB.get( 19,0 )
    # <my_document[#19:0]: emb : ["<my_alist[#33:0]: name : record 1, number : 1>", "<my_alist[#34:0]: name : record 2, number : 2>"]>
    # puts DB.get( 19,0 ){ false  }
    # <my_document[#19:0]: emb : ["#33:0", "#34:0"]>
    #
    #
    def get *rid
      autocomplete = block_given? ? yield :  true
      rid =  rid.join(':')
      rid = rid[1..-1] if rid[0]=="#"
      if rid.rid?
        Api.query( database, "select from #{rid}" ).first &.allocate_model(autocomplete)
      else
        raise Arcade::QueryError "Get requires a rid input", caller
      end
    end

    # ------------------------------  property        ------------------------------------------------- #
    # Adds properties to the type
    #
    #  call via
    #  Api.property <database>, <type>, name1: a_format , name2: a_format
    #
    #  Format is one of
    #   Boolean, Integer, Short, Long, Float, Double, String
    #   Datetime, Binary, Byte, Decimal, Link
    #   Embedded, EmbeddedList, EmbeddedMap
    #
    #   In case of an Error,  anything is rolled back and nil is returned
    #
    def self.property database, type, **args

      begin_transaction database
      success = args.map do | name, format |
        r= execute(database) {" create property #{type.to_s}.#{name.to_s} #{format.to_s} " } &.first
        if r.nil?
          false
        else
          r.keys == [ :propertyName, :typeName, :operation ] && r[:operation] == 'create property'
        end
      end.uniq
      if success == [true]
        commit database
        true
      else
        rollback database
      end


    end

    # ------------------------------ index            ------------------------------------------------- #
    def self.index database, type,  name ,  *properties
      properties = properties.map( &:to_s )
      unique_requested = "unique" if properties.delete("unique")
      unique_requested = "notunique" if  properties.delete("notunique" )
      automatic = true if
      properties << name  if properties.empty?
    end

    def delete rid
      r =  Api.execute( database ){ "delete from #{rid}" }
      success =  r == [{ :count => 1 }]
    end

    # execute a command  which modifies the database
    #
    # The operation is performed via Transaction/Commit
    # If an Error occurs, its rolled back
    #
    def execute   &block
      Api.begin_transaction database
      response = Api.execute database, &block
      # puts response.inspect  # debugging
      r= if  response.is_a? Hash
           _allocate_model res
#         elsif response.is_a? Array
           # remove empty results
#           response.delete_if{|y| y.empty?}
          # response.map do | res |
          #   if res.key? :"@rid"
          #     allocate_model res
          #   else
          #     res
          #   end
          # end
         else
           response
         end
     Api.commit database
     r # return associated array of Arcade::Base-objects
    rescue  Dry::Struct::Error, Arcade::QueryError => e
      Api.rollback database
      logger.error "Execution  FAILED --> #{e.exception}"
      []  #  return empty result
    end

    # returns an array of results
    #
    # detects database-records and  allocates them as model-objects
    #
    def query  query_object
      Api.query database, query_object.to_s
    end

    #  returns an array of rid's   (same logic as create)
    def create_edge  edge_class, from:, to:,  **attributes

      content = attributes.empty? ?  "" : "CONTENT #{attributes.to_json}"
      cr = ->( f, t ) do
        edges = Api.execute( database, "create edge #{edge_class} from #{f.rid} to #{t.rid} #{content}").allocate_model(false) 
        #else
        #  logger.error "Could not create Edge  #{edge_class} from #{f} to #{t}"
        ##  logger.error edges.to_s
        #end
      end
      from =  [from] unless from.is_a? Array
      to =  [to] unless to.is_a? Array

      from.map do | from_record |
        to.map { | to_record | cr[ from_record, to_record ] if  to_record.rid? } if from_record.rid?
      end.flatten

    end


    # query all:  select @rid, *  from {database}

#  not used
 #  def get_schema
 #    query( "select from schema:types" ).map do |a|
 #      puts "a: #{a}"
 #      class_name = a["name"]
 #      inherent_class =  a["parentTypes"].empty? ? [Object,nil] : a["parentTypes"].map(&:camelcase_and_namespace)
 #       namespace, type_name = a["type"].camelcase_and_namespace
 #       namespace= Arcade if namespace.nil?
 #      klass=  Dry::Core::ClassBuilder.new(  name: type_name,
 #                                          parent: nil,
 #                                          namespace:  namespace).call
 #    end
 #  rescue NameError
 #    logger.error "Dataset type #{e} not defined."
 #    raise
 #  end
   #  Postgres is not implemented
   # connects to the database and initialises @connection
    def connection
      @connection
    end

    def connect environment=:development   # environments:  production devel test
      if [:production, :development, :test].include? environment

        #  connect through the ruby  postgres driver
#       c= PG::Connection.new  dbname: Config.database[environment],
#         user: Config.username[environment],
#         password: Config.password[environment],
#         host:  Config.pg[:host],
#         port:  Config.pg[:port]
#
     end
    rescue PG::ConnectionBad => e
      if e.to_s  =~  /Credentials/
        logger.error  "NOT CONNECTED ! Either Database is not present or credentials (#{ Config.username[environment]} / #{Config.password[environment]}) are wrong"
        nil
      else
        raise
      end
    end  # def



  end  # class
end  #  module
