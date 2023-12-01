require 'spec_helper'
require 'database_helper'

RSpec.describe Arcade::Database do
  before(:all) do
    connect
    DB = Arcade::Init.db
    DB.begin_transaction
    begin
    DB.create_type :document, 'test_document'
    DB.create_type :vertex, :test_vertex
    Arcade::TestVertex.delete all: true
    rescue Arcade::QueryError => e
      unless e.message  =~/Type\s+.+\salready\s+exists/
        raise
      end
    end
  end
  after(:all) do
    DB.rollback
  end

  context "It memoises the database"  do
    subject {  Arcade::Database.new( :test )  }
    its( :database ){ is_expected.to eq Arcade::Config.database[:test] }
  end

  context "Create a document type " do

    it "the document type is present" do
      r= DB.hierarchy(type: :document).flatten

      expect(r).to be_an Array
      expect(r).to  include 'test_document'
    end
    it "a dataset record can be created and fetched" do
      r= DB.create 'test_document' ,  name: "Gugo",  age: 54
      expect(r).to match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/    # returns the rid

      rr=  DB.get r

      expect(rr).to be_a   Arcade::TestDocument
      # rid is proper formatted
      expect(rr.rid).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      # and equal to the one retrieved by DB.create
      expect(rr.rid).to eq r
      expect(rr.name).to eq "Gugo"
    end
  end
  context "Create a vertex type " do

    it "the  vertex type is present" do
      r= DB.hierarchy( type: :vertex ).flatten
      expect(r).to be_an Array
      expect(r).to  include 'test_vertex'
    end

    it "insert a dataset" do
      rid= DB.create 'test_vertex',  name: "Gugo",  bes: "Über", age: 54
      expect(rid).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/

      r=  DB.get rid

      expect(r).to be_an  Arcade::TestVertex
      expect(r.attributes).to be_a Hash
      expect(r.attributes.keys).to include :name      # rid is proper formatted
      expect(r.rid).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
    end
  end

  context "Reading a record loads an Arcade::Base-Object" do
    before( :all ){ @rid=  DB.create :test_vertex, name: "parent", age: 54}
    it "retrieves the correct model" do
      r =  DB.get @rid
      expect(r).to be_an Arcade::TestVertex
      expect(r.age).to eq 54
      expect(r.name).to eq 'parent'
    end
  end

  context "Querying the database load Arcade::Base-Objects"   do
    before( :all ){ @rid=  DB.create :test_vertex, name: "parent", age: 54}
    it "retrieves the correct model" do
      r =  DB.query(" select from test_vertex").allocate_model
      expect( r ).to be_an Array
      r.each do | record |
        expect( record ).to be_an Arcade::TestVertex
      end
    end
  end
  context "Basic operations on an edge "  do
    before( :all ) do
      DB.create_type :edge, :test_edge
    end

    it "the edge type is present in the database" do
      r= DB.hierarchy( type: :edge ).flatten
      expect( r ).to be_an Array
      expect( r ).to  include 'test_edge'
    end

    it "insert an edge" do
      rid1= DB.create 'test_vertex',  name: "parent", age: 54
      rid2= DB.create 'test_vertex',  name: "child" , age: 4
      edge = DB.create_edge 'test_edge',  from: rid1,  to: rid2  # the edge ist present in the database

      expect( edge ).to be_an Array
      edge.each do  |e|
        expect( e ).to be_an  Arcade::TestEdge
        ## includes system attributes
        expect( e.attributes ).to include(:rid )
        expect( e.attributes ).to include(:in, :out )
        # rid is proper formatted
        expect(e.rid ).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
        # even a  basic-edge has proper in- and out-attributes
        expect( e.in.rid ).to eq rid2.rid     # to    translates to :in
        expect( e.out.rid ).to eq rid1.rid    # from  translates to :out
      end
    end

    it " add some records and connect them via edges to a central vertex" do
      rid1=  DB.create 'test_vertex',  name: "parent", age: 54
      previous_logger =  Arcade::Database.logger.level
      Arcade::Database.logger.level = Logger::ERROR
      count = 50
      puts "      --> performing #{count} records "
      ( 1 .. count ).each do |i|
#                        Arcade::Api.begin_transaction DB.database
                        vertex=  DB.create 'test_vertex',  name: "child", age: i
                        DB.create_edge 'test_edge',  from: rid1,  to: vertex
 #                       Arcade::Api.commit DB.database
      end

      ### follow all out-links from rid1 , then apply a filter and sort the output
      edges =  DB.query(" select from ( traverse out() from #{rid1} ) where name = 'child'  order by age").allocate_model
      expect( edges.size ).to eq count
      expect( edges.first.age ).to eq 1
      expect( edges.last.age ).to eq count
      expect( edges.first.name ).to eq "child"
      Arcade::Database.logger.level = previous_logger

    end

    it "build a chain of vertices aligned with edges and query it" do
      previous_logger =  Arcade::Database.logger.level
      Arcade::Database.logger.level = Logger::ERROR
      count = 100
      puts "      --> performing #{count} records "
      ## prepare database
      start =  DB.create "test_vertex", name: "chain", age: 0
      ( 1 .. count-1 ).each do | chain |
        next_vertex = DB.create "test_vertex", name: "chain", age: chain
        DB.create_edge "test_edge", from: start, to: next_vertex
        start = next_vertex
      end
      Arcade::Database.logger.level = previous_logger

      ## primitive and ineffective query ( lacking an index, returning an array of Arcade::Base objects )
      primitive =  DB.query "select from test_vertex where name = 'chain' "
      expect( primitive.count ).to eq count

      ## more efficient traverse approach ( returning an array of Arcade::Base objects )
      ## in a real world application, an index at name,age is required nevertheless
      traverse = DB.query " traverse out() from  ( select from test_vertex where name = 'chain' and age=0 ) "
      expect( traverse.count ).to eq count

      ## using the match syntax  ( returns an array of rid's, automatic indices are applied )
      match =  DB.query " match { type: test_vertex, as: c,  where: ( name = 'chain'  ) } return c "
      expect( match.count ).to eq count


    end

  end


end
