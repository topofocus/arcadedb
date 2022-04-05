module Arcade
  ##
  # Implements the PG-Database-Adapter
  #
  #  currently, only attributes of type String are supported
  ##
  class Database
    include ::Logging
    extend Dry::Core::ClassAttributes

    defines :namespace
    defines :environment

    def initialize  environment=:development
      self.class.configure_logger( Config.logger ) if logger.nil?
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
    def types
      #  uses API
      t= Api.query(database){ "select from schema:types"   }
                   .map{ |x| x.transform_keys &:to_sym     }   #  symbolize keys
                   .map{ |y| y.delete_if{|_,b,| b.empty? } }   #  eliminate  empty entries

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


    def execute &block
      Api.execute database, &block
    end

   # def query &block
   #   Api.query database, &block
   # end

    # ------------ create type -----------
    #  returns an Array
    #  Example:  > create_type :vertex, :my_vertex
    #           => [{"typeName"=>"my_vertex", "operation"=>"create vertex type"}] 
    #
    #
    def create_type kind, type
      exe = -> do
        case kind.to_s
        when /^v/
          "create vertex type #{type}"
        when /^d/
          "create document type #{type}"
        when /^e/
          "create edge type #{type}"
        end
      end
      execute &exe
    end

    # ------------ create  -----------
    # returns an rid of the sucessufully  created vertex or document
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



   #  Postgres is not implemented
   # connects to the database and initialises @connection
    def connection
      @connection
    end

    def connect environment=:development   # environments:  production devel test
      if [:production, :development, :test].include? environment

        #  connect through the ruby  postgres driver
        c= PG::Connection.new  dbname: Config.database[environment],
          user: Config.username[environment],
          password: Config.password[environment],
          host:  Config.pg[:host],
          port:  Config.pg[:port]

      end
    rescue PG::ConnectionBad => e
      if e.to_s  =~  /Credentials/
        logger.error  "NOT CONNECTED ! Either Database is not present or credentials (#{ Config.username[environment]} / #{Config.password[environment]}) are wrong"
        nil
      else
        raise
      end
    end  # def

    # impodent query
    #
    # returns an array of results
    def query  query_string
      puts "Query database= #{database}"
      response= Api.query(database){ query_string }
      response.map do |r|
        if r.key? "@rid"
          allocate_model r
        else
          r
        end
      end
    end

    #  returns an array of rid's   (same logic as create)
    def create_edge  edge, from:, to:

      cr = ->( f, t ) do
        e= execute{ "create edge #{edge} from #{f} to #{t}" }
        if e.is_a?(Array) 
        e.first["@rid"]
        else
          logger.error "Could not create Edge from #{f} to #{t}"
          logger.error e
        end
      end
      from =  [from] unless from.is_a? Array
      to =  [to] unless to.is_a? Array

      from.map do | ff |
        if ff.rid?
          to.map  do | tt |
            cr[ff,tt] if  tt.rid?
          end
        end
      end.flatten
    end


    def get rid
      allocate_model( Api.get_record( database, rid) )
    end


    # query all:  select @rid, *  from {database}


   def get_schema
     query( "select from schema:types" ).map do |a|
       puts "a: #{a}"
       class_name = a["name"]
       inherent_class =  a["parentTypes"].empty? ? [Object,nil] : a["parentTypes"].map(&:camelscase_and_namespace)
        namespace, type_name = a["type"].camelcase_and_namespace
        namespace= Arcade if namespace.nil?
       klass=  Dry::Core::ClassBuilder.new(  name: type_name,
                                           parent: nil, 
                                           namespace:  namespace).call
     end
   rescue NameError => e
     logger.error "Dataset type #{e} not defined."
     raise
   end

   private
    def allocate_model response
     # puts "Response #{response}"

      if response.is_a? Hash
        rid =  response["@rid"]
        klass_names =  response["@type"].split('_').map{|y| y[0]=y[0].upcase; y}  #  return an array of potential module/classnames

        namespace, type_name = response["@type"].camelcase_and_namespace
        namespace= Arcade if namespace.nil?
        # choose the apropiate class
        klass=  Dry::Core::ClassBuilder.new(  name: type_name, parent:  nil, namespace:  namespace).call
        # create a new object of that  class with the appropiate attributes
        #  alternative :  use hash.except( "@type", "@cat" )
        klass.new  response.reject{|k,_| ["@type", "@cat"].include? k }
      else
        raise "Dataset #{rid} is either not present or the database connection is broken"
      end
    rescue  Dry::Struct::Error => e
      logger.error "Get #{rid} FAILED --> #{e}"
      nil
    rescue  => e
      puts "Error: #{e}"
      logger.error "Get #{rid} FAILED -->  Model-Class not present"
        basic_type =  case response["@cat"]
                      when "d"
                        :Basicdocument
                      when "v"
                        :Basicvertex
                      when "e"
                        :Basicedge
                      end
        logger.error "Model #{response["@type"]} not defined \n                       Using #{basic_type} instead."
        klass=  Dry::Core::ClassBuilder.new(  name: basic_type,
                                            parent:  nil,
                                         namespace:  Arcade)  #  fix!
                                        .call

        klass.new rid: response.delete( "@rid" ),
                   in: response.delete( "@in"  ),
                  out: response.delete( "@out" ),
               values: response.reject{ |k,_| ["@type", "@cat"].include? k }.transform_keys(&:to_sym)

    end


  end  # class
end  #  module
