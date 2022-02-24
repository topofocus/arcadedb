module Arcade
  ## 
  #        W O R K    I N    P R O G R E S S  
  ##
  class Database
    include ::Logging
    extend Dry::Core::ClassAttributes

    defines :namespace
    defines :environment

    def initialize  environment=:devel
      self.class.configure_logger( Config.logger ) if logger.nil?
     # @connection =  connect environment
      if self.class.environment.nil?    # class attribute is set on the first call
                                        # further instances of Database share the same environment
        self.class.environment  environment
      end
    end
    #  Postgres is not implemented 
   # connects to the database and initialises @connection
   # def connection
   #   @connection
   # end

   # def connect environment=:devel   # environments:  production devel test
   #   if [:production, :devel, :test].include? environment

   #     #  connect through the ruby  postgres driver
   #     c= PG::connect  dbname: Config.database[environment],
   #       user: Config.username[environment],
   #       password: Config.password[environment],
   #       host:  Config.pg[:host],
   #       port:  Config.pg[:port]

   #     #  add the mini-sql-layer
   #     #          MiniSql::Connection.get(c)
   #     #
   #   end
   # rescue PG::ConnectionBad => e
   #   if e.to_s  =~  /Credentials/
   #     logger.error  "NOT CONNECTED ! Either Database is not present or credentials (#{ Config.username[environment]} / #{Config.password[environment]}) are wrong"
   #     nil
   #   else
   #     raise
   #   end
   # end  # def

    # impodent query
    #
    # returns an array of results
    def query  query_string
      Api.query( Config.database[self.class.environment] ){ query_string }
    end

    def get rid
      response = Api.get_record Config.database[self.class.environment], rid
      puts "r: #{response}"
      if response.is_a? Hash
        klass_names =  response["@type"].split('_').map{|y| y[0]=y[0].upcase; y}  #  return an array of potential module/classnames


        klass=  Dry::Core::ClassBuilder.new(  name: response["@type"], parent:  nil, namespace:  Arcade).call

        klass.new  response.reject{|k,_| ["@type", "@cat"].include? k }
      else
        raise "Dataset #{rid} is either not present or the database connection is broken"
      end
    rescue NameError => e
      logger.error "Dataset type #{response["@type"]} not defined."
      raise
    end

    # query all:  select @rid, *  from {database}


   def get_schema
     query( "select from schema:types" ).map do |a|
       class_name = a["name"]
       inherent_class =  a["parentTypes"].empty? ? Object : a["parentTypes"]
       klass=  Dry::Core::ClassBuilder.new(  name: a["type"], parent:  nil, namespace:  Arcade).call
     end
   rescue NameError => e
     logger.error "Dataset type #{e} not defined."
     errors= true
   end


  end  # class
end  #  module
