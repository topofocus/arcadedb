module Arcade
  class Config
    extend Dry::Configurable
    # central place to initialize constants
    #puts "expand: #{File.expand_path(__dir__)}"
    unless Arcade.const_defined?(:ProjectRoot)
      Arcade::ProjectRoot = if defined?( Rails.env )
                              Rails.root
                            else
                              STDERR.puts "Using default (arcadedb gem)  database credentials and settings"
      # logger is not present at this stage
                              Pathname.new( File.expand_path( "../../", __FILE__ ))
      end
    else
      STDERR.puts "Using provided database credentials and settings fron #{Arcade::ProjectRoot}"
    end


    # initialised a hash  { environment => property }
    setting :username, default: :user,      reader: true,
      constructor:  ->( v ) { yml(:environment).map{|x,y|  [x , y[v.to_s]] }.to_h}
    setting :password, default: :password,  reader: true,
      constructor:  ->( v ) { yml(:environment).map{|x,y|  [x , y["pass"]] }.to_h}
    setting :database, default: :database,  reader: true,
      constructor:  ->( v ) { yml(:environment).map{|x,y|  [x , y["dbname"]] }.to_h}
    setting(:base_uri, default: :host ,    reader: true,
            constructor:  ->( v ) { "http://"+yml(:admin)[v]+':'+yml(:admin)[:port].to_s+"/api/v1/" })
    setting :pg,      default:  :pg,       reader: true , constructor:  ->( v ) { yml(v)}
    setting :admin,   default:  :admin,    reader: true , constructor:  ->( v ) { yml(v)}
    setting :logger,  default:  :logger,   reader: true , constructor:  ->( v ) { yml(v) == "rails" ?  Rails.logger : yml(v) }
    setting :namespace, default:  :namespace, reader: true , constructor:  ->( v ) { yml(v)}
     private
    # if a config dir exists, use it
     def self.config_file
       if @cd.nil? 
         (cd = ProjectRoot + "config.yml").exist? || (cd =  ProjectRoot + 'arcade.yml').exist? ||  ( cd = ProjectRoot + 'config' + 'arcade.yml' )
         @cd = cd
       else
         @cd
       end
     end
    def self.yml key=nil
      y= YAML::load_file( config_file )
      key.nil?  ?  y : y[key]
    end
  end
end
