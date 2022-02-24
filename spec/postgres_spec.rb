require 'spec_helper'

def connect dbname: "test"
  args = { adapter: 'postgresql', dbname: dbname }.merge OPT[:pg]
  connection = PG.connect **args
  MiniSql::Connection.get( connection, {} )
end
