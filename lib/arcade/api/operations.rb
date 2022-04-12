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

     def self.logger
       Database.logger
     end
    def self.databases
      get_data 'databases'
    end

    def self.create_database name
      post_data  "create/#{name}"
    end

    def self.drop_database name
      post_data  "drop/#{name}"
    end
    #
    # adds a document to the database
    #
    # specify database-fields as hash-type parameters
    #
    # i.e   Arcade::Api.create_document 'devel', 'documents',  name: 'herta meyer', age: 56, sex: 'f'
    #
    # returns the rid of the inserted dataset
    def self.create_document database, type, **attributes
      payload = { "@type" => type }.merge( attributes ).to_json

      options = if session.nil?
                  { body: payload }.merge( auth ).merge( json )
                else
        { body: payload }.merge( auth ).merge( json ).merge( headers: { "arcadedb-session-id" => session })
                end
      post_data "document/#{database}", options
    end

    # executes a sql-query in the specified database
    #
    # the  query is provided as block
    #
    # returns an Array of results (if propriate)
    # i.e
    # Arcade::Api.execcute( "devel" ) { 'select from test  ' }
    #  =y [{"@rid"=>"#57:0", "@type"=>"test", "name"=>"Hugo"}, {"@rid"=>"#60:0", "@type"=>"test", "name"=>"Hubert"}]
    #
    def self.execute database
      pl = provide_payload(yield)
      options =   { body: pl }.merge( auth ).merge( json )
      unless session.nil?
        options = options.merge( headers: { "arcadedb-session-id" => session })
      end
      post_data "command/#{database}" , options
    end

    # same for idempotent queries
    def self.query database
      options = { body: provide_payload(yield)  }.merge( auth ).merge( json ) 
      post_data   "query/#{database}" , options
    end

    # fetches a record by providing  database and  rid  
    # and returns the result as hash
    #
    def self.get_record database, rid
      rid =  rid[1..-1] if rid[0]=="#"
      get_data  "document/#{database}/#{rid}"
    end
    # Arcade::Api.get_record "OpenBeer", "#555:11"  returns
    #  {"@out"=>0,
    #   "@rid"=>"#554:11",
    #   "@in"=>0,
    #   "@type"=>"hc_portfolio",
    #   "@cat"=>"v",
    #   "positions"=> [...]...  (weitere Felder)
    #

    def self.insert_record database,  type, **args
#      payload =  { "@type" => type }.merge( args).to_json
      post_data "document/#{database}", body: payload
    end

    #  ------------ Transaction -------------------
    #
    def self.begin_transaction database
      result  = Typhoeus.post Arcade::Config.base_uri + "begin/#{database}", auth
      @session_id = result.headers["arcadedb-session-id"]

      # returns the session-id 
    end

    def self.session
      @session_id
    end

    def self.commit database
    options =  auth.merge( headers: { "arcadedb-session-id" => session })
      post_data  "commit/#{database}", options
      @session_id =  nil
    end

    def  self.rollback database
      options =  auth.merge( headers: { "arcadedb-session-id" => session })
      post_data  "rollback/#{database}", options
      @session_id =  nil
    end

    private

    def self. provide_payload( the_yield, action: :post ) 
      the_yield =  { :query => the_yield } unless the_yield.is_a? Hash
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

    def self.post_json command, options
      result = self.post_data Arcade::Config.base_uri + command , auth.merge(options).merge(json)
    end

    def self.get_json command
      result = Typhoeus.get Arcade::Config.base_uri + "query", { body: provide_payload(command)}.merge(auth).merge(json)
    end
#  not tested
    def self.delete_data command
      result  = Typhoeus.delete Arcade::Config.base_uri + command, auth
      analyse_result(result, command)
    end

    def self.post_data command, options = auth
 #     puts "Post DATA #{command} #{options}"
      result  = Typhoeus.post Arcade::Config.base_uri + command, options
      analyse_result(result, command)
    end
    #  todo raise exceptions   instead of returning the error-string
    def self.analyse_result r, command
        if r.success?
#          puts "CODE"
#          puts r.response_code
          return nil  if r.response_code == 204  # no content
#          puts r.methods
#          puts r.response_body["result"].inspect
          result = JSON.parse( r.response_body )["result"]
          if result.is_a?(Hash) && result.key?("result")
          #  return  the  response
           result['result'] 
          elsif result == [{}]
           []
          else
            result
          end
        elsif r.timed_out?
          logger.error "Timeout Error"
          []
        elsif r.response_code > 0
 #         puts r.inspect
          logger.error  "Execution Failure – Code: #{ r.response_code } – #{r.status_message} "
         # puts "Body: "+ r.response_body.to_s  unless r.response_body.empty?
          body =  JSON.parse( r.response_body ) unless r.response_body.empty?

          puts "Description: "+ body["detail"] if body.is_a? Hash
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
  end
end
