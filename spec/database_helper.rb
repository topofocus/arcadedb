
def clear_arcade
  #  delete testdatabase and restore it
  databases =  Arcade::Api.databases
  if databases.nil?
  puts "Edit Credentials in config.yml"
  Kernel.exit
  end
  if  databases.include?(Arcade::Config.database[:test])
    Arcade::Api.drop_database Arcade::Config.database[:test] 
  end
  Arcade::Api.create_database Arcade::Config.database[:test]
end
