module Arcade
 module  Api
   extend Primitives
=begin
  This is a simple admin interface

  $ Arcade::Api.databases                   # returns an Array of known databases
  $ Arcade::Api.create_database <a string>  # returns true if succesfull
  $ Arcade::Api.drop_database   <a string>  # returns true if successfull

  $ Arcade::Api.create_document <database>, <type>,  attributes
  $ Arcade::Api.execute( <database>  [, session_id:  some_session_id ]) { <query> }
  $ Arcade::Api.query( <database> ) { <query> }
  $ Arcade::Api.get_record <database>,  rid  #  returns a hash


  <query> is  either a  string
          or a hash   { :query => " ",
                        :language => one of :sql, :cypher, :gmelion: :neo4j ,
                        :params =>   a  hash of parameters,
                        :limit => a number ,
                        :serializer:  one of :graph, :record }

=end

    # ------------------------------ Service methods  ------------------------------------------------- #
    # ------------------------------                  ------------------------------------------------- #
    # ------------------------------ databases        ------------------------------------------------- #
    #  returns an array of databases present on the database-server                                     #

    def self.databases
      get_data 'databases'
    end

    # ------------------------------ database?        ------------------------------------------------- #
    #  returns true if the database exists                                                              #

    def self.database? name
      get_data "exists/#{name}"
    end

    # ------------------------------ create database  ------------------------------------------------- #
    #  creates a database if not present                                                                #
    def self.create_database name
      return if databases.include?( name.to_s )
      payload = { "command" => "create database #{name}" }
        post_data  "server", payload
    rescue  Arcade::QueryError => e
      logger.fatal "Create database #{name} through \"POST create/#{name}\" failed"
      logger.fatal  e
      raise
    end

    # ------------------------------  drop  database  ------------------------------------------------- #
    #  deletes the given database                                                                       #
    def self.drop_database name
      return unless databases.include?( name.to_s )
      payload = {"command" => "drop database #{name}" }
       post_data  "server",  payload
    rescue Arcade::QueryError => e
      logger.fatal "Drop database #{name} through \"POST drop database/#{name}\" failed"
      raise
    end

    # ------------------------------  execute         ------------------------------------------------- #
    # executes a sql-query in the specified database
    #
    # the  query is provided as block
    #
    # returns an Array of results (if propriate)
    # i.e
    # Arcade::Api.execute( "devel" ) { 'select from test  ' }
    #  =y [{"@rid"=>"#57:0", "@type"=>"test", "name"=>"Hugo"}, {"@rid"=>"#60:0", "@type"=>"test", "name"=>"Hubert"}]
    #
    def self.execute database, session_id: nil
      pl = provide_payload(yield)
      if session_id.nil?
        post_data "command/#{database}" , pl
      else
        post_transaction "command/#{database}" , pl, session_id: session_id
      end
    end

    # ------------------------------  query           ------------------------------------------------- #
    # same for idempotent queries
    def self.query database, query, session_id: nil
#      if session_id.nil?
        get_data   "query/#{database}/sql/" + provide_payload(query, action: :get)[:query]
 #     else
 #       post_transaction "query/#{database}" , provide_payload(query), session_id: session_id
 #     end
    end

    # ------------------------------  create Document   ------------------------------------------------- #
    # adds a record ( document, vertex or edge ) to the specified database type
    #
    # specify database-fields as hash-type parameters
    #
    # i.e   Arcade::Api.create_record 'devel', 'documents',  name: 'herta meyer', age: 56, sex: 'f'
    #
    # returns the rid of the inserted dataset
    #
    def self.create_document database, type, session_id: nil, **attributes
        content = "CONTENT #{ attributes.to_json }"
        result = execute( database, session_id: session_id ){ "INSERT INTO #{type} #{content} "}
        result.first[:@rid]   #  emulate the »old« behavior of the /post/create_document api endpoint
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
      if rid.rid?
        get_data( "query/#{database}/sql/" + URI.encode_uri_component("select from #{rid}")) &.first
      else
        raise Error "Get requires a rid input"
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

      s= begin_transaction database
      success = args.map do | name, format |
        r= execute(database, session_id: s) {" create property #{type.to_s}.#{name.to_s} #{format.to_s} " } &.first
        r.nil? ?  false : r[:operation] == 'create property'
      end.uniq
      if success == [true]
        commit database, session_id: s
        true
      else
        rollback database log: false, session_id: s
        false
      end


    end

    # ------------------------------ index            ------------------------------------------------- #
    def self.index database, type,  name ,  *properties
      properties = properties.map( &:to_s )
      unique_requested = "unique" if properties.delete("unique")
      unique_requested = "notunique" if  properties.delete("notunique" )
      automatic = true if
      properties << name  if properties.empty?
      success = execute(database) {" create index IF NOT EXISTS on #{type} (#{properties.join(', ')}) #{unique_requested}" } &.first
#      puts "success: #{success}"
       success[:operation] == 'create index'

    end


    private

     def self.logger
       Database.logger
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
                                    if action == :post
                                      [ :command, value ]
                                    else
                                      [ :query, URI.encode_uri_component(value )]
                                    end
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
                                    if [:sql, :cypher, :gremlin, :neo4j, :sqlscript, :graphql, :mongo ].include? value.to_sym
                                      [ :language,  value.to_sym ]
                                    end
                                  end # case
                                end .to_h ) # map
    end



    def self.auth
       @a ||= { httpauth: :basic,
         username: Config.admin[:user],
         password: Config.admin[:pass] }
    end

  end
end
