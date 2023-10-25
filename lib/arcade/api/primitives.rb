module Arcade
 module  Api
   module Primitives

  # This module handles the interaction with the database through HTTPX
  #
   # ------------------------------  http ------------------------------------------------------------ #
   # persistent http handle to the database

    def http
      break_on = -> (response) { response.status == 500  }
      @http ||= HTTPX.plugin(:basic_auth).basic_auth(auth[:username], auth[:password])
                  .plugin(:persistent)
                  .plugin(:circuit_breaker)
   #               .plugin(:circuit_breaker, circuit_breaker_break_on: break_on)
    end

    # ------------------------------  get data -------------------------------------------------------- #
    def get_data command
      response = http.get( Config.base_uri + command )
      response.raise_for_status

      JSON.parse( response.body, symbolize_names: true )[:result]
      #      alternative to `raise for status `
#      case response = http.basic_auth(auth[:username], auth[:password]).get( Config.base_uri + command )
#      in { status: 200..203, body:  }
#        puts "success: #{JSON.parse(body, symbolize_names: true)[:result]}"
#      in { status: 400..499, body:  }
#        puts "client error: #{body.json}"
#      in { status: 500.., body:  }
#          puts "server error: #{body.to_s}"
#      in { error: error  }
#          puts "error: #{error.message}"
#      else
#          raise "unexpected: #{response}"
#      end
#      puts "result : #{response}"
#      puts "code: #{response.status}"
#      analyse_result(response, command)
    end

    # ------------------------------ post data -------------------------------------------------------- #
    def post_data command,  payload
#      http = HTTPX.plugin(:basic_auth)
 #                 .basic_auth(auth[:username], auth[:password])
      response = http.post( Config.base_uri + command, json:  payload )
      response.raise_for_status
      JSON.parse( response.body, symbolize_names: true )[:result]
    end

    # ------------------------------ transaction      ------------------------------------------------- #
    #
    def begin_transaction database
      result  = http.post Config.base_uri + "begin/#{database}"
      @session_id = result.headers["arcadedb-session-id"]
      # returns the session-id
    end

    # ------------------------------ post transaction ------------------------------------------------- #
    def post_transaction command, params, session_id= @session_id
     # http = HTTPX.plugin(:basic_auth)
     #             .basic_auth(auth[:username], auth[:password])
     #             .with( headers: { "arcadedb-session-id"=>session }, debug_level: 1)
      http_a = http.with(  headers: { "arcadedb-session-id" => session_id } , debug_level: 1)
      response = http_a.post( Config.base_uri + command, json:  params )
      response.raise_for_status
      JSON.parse( response.body, symbolize_names: true )[:result]

    end

    # ------------------------------ commit           ------------------------------------------------- #
    def commit database, session_id = @session_id
      http_a = http.with(  headers: { "arcadedb-session-id" => session_id } , debug_level: 1)
      response = http_a.post( Config.base_uri + "commit/#{database}" )
      response.raise_for_status
      @session_id =  nil
      response.status  #  returns 204 --> success
                       #          403 --> incalid credentials
                       #          500 --> Transaction  not begun

    end

    # ------------------------------ rollback         ------------------------------------------------- #
    def rollback database, session_id = @session_id, publish_error=true
    #  http = HTTPX.plugin(:basic_auth)
    #              .basic_auth(auth[:username], auth[:password])
    #              .with( headers: { "arcadedb-session-id"=>session_id }, debug_level: 1)
      http_a = http.with(  headers: { "arcadedb-session-id" => session_id } , debug_level: 1)
      response = http_a.post( Config.base_uri + "rollback/#{database}" )
      response.raise_for_status
      @session_id =  nil
      logger.error  "A Transaction has been rolled back"  # if publish_error
      response.status
    end
  end
 end
end

