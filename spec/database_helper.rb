
def  connect
  #  create testdatabase and connect
  databases =  Arcade::Api.databases
  if databases.nil?
  puts "Edit Credentials in config.yml"
  Kernel.exit
  end
    Arcade::Api.create_database Arcade::Config.database[:test] if  !databases.include?(Arcade::Config.database[:test])
    Arcade::Init.connect :test

end
