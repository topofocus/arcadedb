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
      if self.class.environment.nil?    # class attribute is set on the first call
                                        # further instances of Database share the same environment
        self.class.environment  environment
      end
      @session_id = nil #  declare session_id
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
      if @types.nil? || refresh
       @types = Api.query(database, "select from schema:types"   )
                   .map{ |y| y.delete_if{|_,b,| b.blank? } }   #  eliminate  empty entries
      end
      @types
      ## upon startup, this is the first access to the database-server
    rescue NoMethodError => e
      logger.fatal "Could not read Database Types. \n Is the database running?"
      Kernel.exit
    end

    def indexes refresh=false
      types(refresh).find_all{|x| x.key? :indexes }.map{|y| y[:indexes]}.flatten
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
      dbe= Api.execute database, &exe
      types( true )  # update cached schema
      dbe

    rescue Arcade::QueryError => e
       if e.message  =~/Type\s+.+\salready\s+exists/
        Arcade::Database.logger.debug "Database type #{type} already present"
       else
         raise
       end
    end

    alias create_class create_type

    # ------------ drop type  -----------
    #  delete any record prior to the attempt to drop a type.
    #  The `unsafe` option is not implemented.
    def drop_type  type
      Api.execute database, "drop type #{type} if exists"
    end

    # ------------------------------  transaction ----------------------------------------------------- #
    #  Encapsulates simple transactions
    #
    #  nested transactions are not supported.
    #  * use the low-leve api.begin_tranaction for that purpose
    #  * reuses an existing transaction
    #
    def begin_transaction
      @session_id ||= Api.begin_transaction database
    end
    # ------------------------------  commit      ----------------------------------------------------- #
    def commit
     r = Api.commit( database, session_id: session)
      @session_id = nil
     true if r == 204
     end

    # ------------------------------  rollback    ----------------------------------------------------- #
    #
    def  rollback
     r = Api.rollback( database, session_id: session)
     @session_id = nil
     true if r == 500
    rescue HTTPX::HTTPError => e
      raise
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
      Api.create_document database, type,  session_id: session, **params
    end

    # ------------------------------  insert     ------------------------------------------------------ #
    #
    # translates the given parameters to
    # INSERT INTO [TYPE:]<type>|BUCKET:<bucket>|INDEX:<index>
    #   [(<field>[,]*) VALUES (<expression>[,]*)[,]*]|
    #   [CONTENT {<JSON>}|[{<JSON>}[,]*]]
    #
    #   :from and :return are not supported
    #
    # If a transaction is active, the insert is executed in that context.
    # Nested transactions are not supported
    def insert  **params

      content_params = params.except( :type, :bucket, :index, :from, :return, :session_id )
      target_params = params.slice( :type, :bucket, :index )
#      session_id = params[:session_id]   # extraxt session_id  --> future-use? 
      if  target_params.empty?
        raise "Could not insert: target missing (type:, bucket:, index:)"
      elsif content_params.empty?
        logger.error "Nothing to Insert"
      else
        content =  "CONTENT #{ content_params.to_json }"
        target =  target_params.map{|y,z|  y==:type ?  z : "#{y.to_s} #{ z } "}.join
        result = Api.execute( database, session_id: session ){ "INSERT INTO #{target} #{content} "}
        result &.first.allocate_model(false)
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
        Api.query( database, "select from #{rid}", session_id: session ).first &.allocate_model(autocomplete)
      else
        raise Arcade::QueryError "Get requires a rid input", caller
      end
    end

    # ------------------------------  get        ------------------------------------------------------ #
    #
    #  Delete the specified rid
    #
    def delete rid
      r =  Api.execute( database, session_id: session ){ "delete from #{rid}" }
      success =  r == [{ :count => 1 }]
    end

    # ------------------------------  transmit   ------------------------------------------------------ #
    # transmits a command  which potentially modifies the database
    #
    # Uses the given session_id for transaction-based operations
    #
    # Otherwise just performs the operation

    def transmit   &block
      response = Api.execute database,  session_id: session, &block
      if  response.is_a? Hash
           _allocate_model res
      else
           response
      end
    end
    # ------------------------------  execute    ------------------------------------------------------ #
    # execute a command  which modifies the database
    #
    # The operation is performed via Transaction/Commit
    # If an Error occurs, its rolled back
    #
    # If a transaction is already active, a nested transation is initiated
    #
    def execute   &block
      # initiate a new transaction
     s= Api.begin_transaction database
      response = Api.execute database,  session_id: s,  &block
      r= if  response.is_a? Hash
           _allocate_model response
         else
           response
         end
     if Api.commit( database, session_id: s) == 204
        r # return associated array of Arcade::Base-objects
     else
       []
     end
    rescue  Dry::Struct::Error, Arcade::QueryError => e
      Api.rollback database, session_id: s, log: false
      logger.info "Execution  FAILED -->  Status #{e.status}"
      []  #  return empty result
    end

    # returns an array of results
    #
    # detects database-records and  allocates them as model-objects
    #
    def query  query_object
      Api.query database, query_object.to_s, session_id: session
    end

    #  returns an array of rid's   (same logic as create)
    def create_edge  edge_class, from:, to:,  **attributes

      content = attributes.empty? ?  "" : "CONTENT #{attributes.to_json}"
      cr = ->( f, t ) do
        begin
          cmd = -> (){  "create edge #{edge_class} from #{f.rid} to #{t.rid} #{content}" }
        edges = transmit( &cmd ).allocate_model(false)
        rescue Arcade::QueryError => e
          raise unless e.message =~ /Found duplicate key/
         puts "#"+e.detail.split("#").last[0..-3]
        end
      end
      from =  [from] unless from.is_a? Array
      to =  [to] unless to.is_a? Array

      from.map do | from_record |
        to.map { | to_record | cr[ from_record, to_record ] if  to_record.rid? } if from_record.rid?
      end.flatten

    end

    def session
      @session_id
    end

    def session?
      !session.nil?
    end
  end  # class
end  #  module
