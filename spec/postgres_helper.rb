require 'spec_helper'

def connect dbname= "test"
  args = { dbname: dbname }.merge( OPT )
  connection = PG.connect **args
  #MiniSql::Connection.get( connection, {} )

rescue PG::ConnectionBad  => e
  puts "Server is not running"
  connection = nil

end
