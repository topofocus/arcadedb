require 'spec_helper'

###
###   Postgres driver is not implemented yet
## 
RSpec.describe Arcade do
  context "Postgres is loaded properly" do
    it { expect( PG ).to be_a Module  }
  end


  context 'connect to the db' do
    it  "can connect to the server" do
      database =  Arcade::Database.new(:test)
      connection =  database.connection
      expect( connection ).to be_a PG::Connection

      #      puts connection.methods
    end

    context "list tables" do
      before(:all) do
        database =  Arcade::Database.new(:test)
        @connection =  database.connection
        @connection.exec "drop type test UNSAFE" rescue nil
      end

      it "Add a vertex and check again" do
        result = @connection.exec "create vertex type test"
        expect( result ).to be_a PG::Result
        types= result.map{|x|  x }
        expect( result.entries.first['operation']).to eq "create vertex type"
        puts "txpes: #{result.entries}"
      end
      it "Analyse Schema:types on an empty database" do
        r= @connection.exec( "select from schema:types" )
        puts "entries: #{r.entries}"
        expect(  r ).to be_a  PG::Result

        result =  r.entries
        expect( result ).to be_an Array
        result.each do |x|
          expect( x.keys ).to eq  ["name", "type", 'parentTypes',"properties", 'indexes']
        end
      end  # it

      it "add a record to test vertex" do
        result = @connection.exec "create vertex test set name = 'Hugo', age = 35, length = 165.45"
        puts "entries: #{result.entries}"
        puts result["age"].encode  "locale", "UTF16"

      end
    end
  end
end
