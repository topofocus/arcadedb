module Arcade

  # Arcade::Init.connect  environment
  #  --------------------------------
  # initializes the database connection
  # and returns the active database handle
  #
  # The database cannot switched later
  #
  #
  # Arcade::Init.db
  #  --------------
  # returns an instance of the database handle
  #
  class Init
    extend Dry::Core::ClassAttributes
    defines :db        # database handle
    defines :models    # static array of database name for arcade-model classes

    def self.connect e= :development

      env =  if e.to_s =~ /^p/
               :production
             elsif e.to_s =~ /^t/
               :test
             else
               :development
             end

      # set the class attributes
      models Base.descendants.map{|x| x.to_s.split("Arcade::").last }
      db Database.new(env)
    end

  end

  # Provides method  `db` to every Model class
  class Base
    def self.db
      Init.db
    end
    # expose db  to instance methods as well
    private  define_method :db, &method(:db)
    private_class_method  :db
  end
  # Provides method  `db` to every Query-Object
  class Query
    def db
      Init.db
    end
  end

end
