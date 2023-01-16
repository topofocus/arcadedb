module Arcade
  class Config
    extend Dry::Configurable
    # central place to initialize constants
    #
    # ProjectRoot has to be a Pathname-Object
    #
    #puts "expand: #{File.expand_path(__dir__)}"
    unless Arcade.const_defined?( :ProjectRoot )
      Arcade::ProjectRoot = if defined?( Rails.env )
                              Rails.root
                            else
                              STDERR.puts "Using default (arcadedb gem)  database credentials and settings"
      # logger is not present at this stage
                              Pathname.new(  File.expand_path( "../../", __FILE__ ))
      end
    else
      STDERR.puts "Using provided database credentials and settings fron #{Arcade::ProjectRoot}"
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
    setting :pg,      default:  :pg,       reader: true , constructor:  ->(v) { yml(v) }
    setting :admin,   default:  :admin,    reader: true , constructor:  ->(v) { yml(v) }
    setting :logger,  default:  :logger,   reader: true ,
      constructor:  ->(v) do
                            if defined?( Rails.env )
                              Rails.logger
                            elsif Object.const_defined?(:Bridgetown)
                            else
                              yml(v)
                            end
                          end
    setting :namespace, default:  :namespace, reader: true , constructor:  ->(v) { yml(v) }
    setting :secret, reader: true,  default: 12, constructor:  ->(v) { seed(v) }
     private
    # if a config dir exists, use it
     def self.config_file
       if @cd.nil?
         ( cd =  ProjectRoot + 'arcade.yml' ).exist? ||
         ( cd =  ProjectRoot + 'config' + 'arcade.yml' ).exist? ||
         ( cd =  ProjectRoot + "config.yml" )
          @cd = cd
       else
         @cd
       end
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
