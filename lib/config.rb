module Arcade
  class Config
    extend Dry::Configurable
  # central place to initialize constants
    unless Arcade.const_defined?(:ProjectRoot)
      Arcade::ProjectRoot = File.expand_path( "../../", __FILE__ ) 
      # logger is not present at this stage
      STDERR.puts "Using default database credentials and settings fron #{Arcade::ProjectRoot}"
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
    setting :logger , default:  :logger,   reader: true , constructor:  ->( v ) { yml(v)}


    private
    def self.yml key=nil
      y= YAML::load_file( ProjectRoot+"/config.yml")
      key.nil?  ?  y : y[key]
    end
  end

end
