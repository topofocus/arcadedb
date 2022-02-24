require 'spec_helper'

###
###   Postgres driver is not implemented yet
## 
#RSpec.describe Arcade do
#  context "Postgres is loaded properly" do
#    it { expect( PG ).to be_a Module  }
#  end
#
#
#  context 'connect to the db' do
#    it  "can connect to the server" do
#      database =  Arcade::Database.new(:test)
#      connection =  database.connection
#      expect( connection ).to be_a PG::Connection
#
##      puts connection.methods
#    end
#
#    context "list tables" do
#      before(:all) do
#        database =  Arcade::Database.new(:test)
#        @connection =  database.connection
#      end
#
#      it "Analyse Schema:types on an empty database" do
#        r= @connection.exec( "select from schema:types" ) {{|x| x.map{|z,|  z }}
#         expect(  r ).to be_an Array
#         expect(  r ).to be empty
#        end
#      end
#
#      it "Add a vertex and check again" do
#        @connection.exec "create vertex test"
#
#          types= result.map{|x|  x } 
#         expect(  types ).to be empty
#         expect( result ).to be_a String
#        end
#
#      end
#    end
#  end
#end
