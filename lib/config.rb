module Arcade
  class Config
    extend Dry::Configurable
    # central place to initialize constants
    #
    # ProjectRoot should to be a Pathname-Object and has to be defined before `arcadedb`  is required
    #
    #puts "expand: #{File.expand_path(__dir__)}"
    unless Object.const_defined?( :ProjectRoot )
      ::ProjectRoot = if defined?( Rails.env )
                              Rails.root
                            else
                              STDERR.puts "Using default (arcadedb gem)  database credentials and settings"
      # logger is not present at this stage
                              Pathname.new(  File.expand_path( "../../", __FILE__ ))
      end
    else
      STDERR.puts "Using provided database credentials and settings from #{::ProjectRoot}"
    end


    # initialised a hash  { environment => property }
    setting :username, default: :user,      reader: true,
      constructor:  ->(v) { yml(:environment).map{|x,y|  [x , y[v.to_s]] }.to_h }
    setting :password, default: :password,  reader: true,
      constructor:  ->(v) { yml(:environment).map{|x,y|  [x , y["pass"]] }.to_h }
    setting :database, default: :database,  reader: true,
      constructor:  ->(v) { yml(:environment).map{|x,y|  [x , y["dbname"]] }.to_h }
    setting(:base_uri, default: :host ,    reader: true,
            constructor:  ->(v) { "http://"+yml(:admin)[v]+':'+yml(:admin)[:port].to_s+"/api/v1/" })
    setting :autoload,      default: :autoload,       reader: true , constructor:  ->(v) { yml(v) }
    setting :pg,      default:  :pg,       reader: true , constructor:  ->(v) { yml(v) }
    setting :admin,   default:  :admin,    reader: true , constructor:  ->(v) { yml(v) }
    setting :logger,  default:  :logger,   reader: true ,
      constructor:  ->(v) do
                            if defined?( Rails.env )
                              Rails.logger
                            elsif Object.const_defined?(:Bridgetown)
                            else
                              output = yml(v)
                              if output.upcase == 'STDOUT'
                                Logger.new STDOUT
                              else
                                Logger.new File.open( output, 'a' )
                              end
                            end
                          end
    setting :namespace, default:  :namespace, reader: true , constructor:  ->(v) { yml(v) }
    setting :secret, reader: true,  default: 12, constructor:  ->(v) { seed(v) }
     private
     # if a config dir exists, use it.
     # Standard:  ProjectRoot/config.yml
     def self.config_file

       configdir =  -> do
         pr =  ::ProjectRoot.is_a?(Pathname)?  ::ProjectRoot : Pathname.new( ::ProjectRoot )
         ( cd =  pr + 'arcade.yml' ).exist? || ( cd =   pr + 'config' + 'arcade.yml' ).exist? || ( cd =   pr + 'config.yml' )
         cd
       end

       @cd ||= configdir[]
     end

    def self.yml key=nil
      y= YAML::load_file( config_file )
      key.nil?  ?  y : y[key]
    end
    def self.seed( key= nil )
      SecureRandom.hex( 40 )
    end
  end
end
