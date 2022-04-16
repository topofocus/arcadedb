module Arcade
 module  Api
=begin
  This is a simple admin interface

  $ Arcade::Api.databases                   # returns an Array of known databases
  $ Arcade::Api.create_database <a string>  # returns true if succesfull
  $ Arcade::Api.drop_database   <a string>  # returns true if successfull

  $ Arcade::Api.create_document <database>, <type>,  attributes
  $ Arcade::Api.execute( <database> ) { <query> }
  $ Arcade::Api.query( <database> ) { <query> }
  $ Arcade::Api.get_record <database>,  rid  #  returns a hash


  <query> is  either a  string
          or a hash   { :query => " ",
                        :language => one of :sql, :cypher, :gmelion: :neo4j ,
                        :params =>   a  hash of parameters,
                        :limit => a number ,
                        :serializer:  one of :graph, :record }

=end

    #include HTTParty

    def self.databases
      get_data 'databases'
    end

    def self.create_database name
      post_data  "create/#{name}"
    end

    def self.drop_database name
      post_data  "drop/#{name}"
    end
    # ------------------------------  create document ------------------------------------------------- #
    # adds a document to the database
    #
    # specify database-fields as hash-type parameters
    #
    # i.e   Arcade::Api.create_document 'devel', 'documents',  name: 'herta meyer', age: 56, sex: 'f'
    #
    # returns the rid of the inserted dataset
    # 
    def self.create_document database, type, **attributes
      payload = { "@type" => type }.merge( attributes ).to_json
      logger.info "C: #{payload}"
      options = if session.nil?
                  { body: payload }.merge( auth ).merge( json )
                else
        { body: payload }.merge( auth ).merge( json ).merge( headers: { "arcadedb-session-id" => session })
                end
      post_data "document/#{database}", options
    end

    # ------------------------------  execute         ------------------------------------------------- #
    # executes a sql-query in the specified database
    #
    # the  query is provided as block
    #
    # returns an Array of results (if propriate)
    # i.e
    # Arcade::Api.execcute( "devel" ) { 'select from test  ' }
    #  =y [{"@rid"=>"#57:0", "@type"=>"test", "name"=>"Hugo"}, {"@rid"=>"#60:0", "@type"=>"test", "name"=>"Hubert"}]
    #
    def self.execute database, query=nil
      pl = query.nil? ? provide_payload(yield) : provide_payload(query)
      options =   { body: pl }.merge( auth ).merge( json )
      unless session.nil?
        options = options.merge( headers: { "arcadedb-session-id" => session })
      end
      post_data "command/#{database}" , options
    end

    # ------------------------------  query           ------------------------------------------------- #
    # same for idempotent queries
    def self.query database, query
      options = { body: provide_payload(query)  }.merge( auth ).merge( json )
      post_data   "query/#{database}" , options
    end

    # ------------------------------  get_record      ------------------------------------------------- #
    # fetches a record by providing  database and  rid
    # and returns the result as hash
    #
    # > Api.get_record 'devel', '225:6'
    # > Api.get_record 'devel', 225, 6
    # > Api.get_record 'devel', '#225:6'
    #     => {:@out=>0, :@rid=>"#225:6", :@in=>0, :@type=>"my_names", :name=>"Zaber", :@cat=>"v"}

    def self.get_record database, *rid
      rid =  rid.join(':')
      rid = rid[1..-1] if rid[0]=="#"
      get_data  "document/#{database}/#{rid}"
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
      success = execute(database) {" create index  if not exists `#{type.to_s}[#{name.to_s}]` on #{type} ( #{properties.join(',')} ) #{unique_requested}" } &.first
     # puts "success: #{success}"
      success && success.keys == [ :totalIndexed, :name, :operation ] &&   success[:operation] == 'create index' 

    end


    # ------------------------------ transaction      ------------------------------------------------- #
    #
    def self.begin_transaction database
      result  = Typhoeus.post Arcade::Config.base_uri + "begin/#{database}", auth
      @session_id = result.headers["arcadedb-session-id"]

      # returns the session-id 
    end


    # ------------------------------ commit           ------------------------------------------------- #
    def self.commit database
    options =  auth.merge( headers: { "arcadedb-session-id" => session })
      post_data  "commit/#{database}", options
      @session_id =  nil
    end

    # ------------------------------ rollback         ------------------------------------------------- #
    def  self.rollback database, publish_error=true
      options =  auth.merge( headers: { "arcadedb-session-id" => session })
      post_data  "rollback/#{database}", options
      @session_id =  nil
      error "A Transaction has been rolled back" , :commit  if publish_error
    end

    private

     def self.logger
       Database.logger
     end

    def self.session
      @session_id
    end

    def self. provide_payload( the_yield, action: :post )
      unless the_yield.is_a? Hash
        logger.info "Q: #{the_yield}"
        the_yield =  { :query => the_yield }
      end
      { language: 'sql' }.merge( 
                                the_yield.map do | key,  value |
                                  case key
                                  when :query
                                   action == :post ? [ :command, value ] : [ :query, value ]
                                  when :limit
                                    [ :limit , value ]
                                  when :params
                                    if value.is_a? Hash
                                      [ :params, value ]
                                    end
                                    # serializer (optional) specify the serializer used for the result:
                                    #  graph: returns as a graph separating vertices from edges
                                    #  record: returns everything as records
                                    # by default it’s like record but with additional metadata for vertex records,
                                    # such as the number of outgoing edges in @out property and total incoming edges 
                                    # in @in property. This serialzier is used by Studio
                                  when :serializer
                                    if [:graph, :record].include? value.to_sym
                                      [ :serializer, value.to_sym ]
                                    end
                                  when :language
                                    if [:sql, :cypher, :gremlin, :neo4j ].include? value.to_sym
                                      [ :language,  value.to_sym ]
                                    end
                                  end # case
                                end .to_h ).to_json # map
    end

    def self.get_data command, options = auth
      result  = Typhoeus.get Arcade::Config.base_uri + command, options
      analyse_result(result, command)
    end


    def self.post_data command, options = auth
     # puts "Post DATA #{command} #{options}"   # debug
      result  = Typhoeus.post Arcade::Config.base_uri + command, options
      analyse_result(result, command)
    end

    #  todo raise exceptions   instead of logging the error-message
    def self.analyse_result r, command
        if r.success?
          return nil  if r.response_code == 204  # no content
          result = JSON.parse( r.response_body, symbolize_names: true )[:result]
          if result == [{}]
           []
          else
            result
          end
        elsif r.timed_out?
          error "Timeout Error"
          []
        elsif r.response_code > 0
#          logger.error  "Execution Failure – Code: #{ r.response_code } – #{r.status_message} "
          body =  JSON.parse( r.response_body, symbolize_names: true  ) unless r.response_body.empty?
          logger.error   body[:detail]  if body.is_a? Hash
        end
    end
    def self.auth
       @a ||= { httpauth: :basic,
         username: Arcade::Config.admin[:user],
         password: Arcade::Config.admin[:pass] }
    end

    def self.json
      { headers: { "Content-Type" => "application/json"} }
    end
#  not tested
    def self.delete_data command
      result  = Typhoeus.delete Arcade::Config.base_uri + command, auth
      analyse_result(result, command)
    end
  end
end
