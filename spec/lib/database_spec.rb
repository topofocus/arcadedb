require 'spec_helper'

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

RSpec.describe Arcade::Database do
  before(:all) do
    clear_arcade
    DB = Arcade::Database.new :test
  end

  context "It memoises the database" do
    subject {  Arcade::Database.new( :test )  }
    its( :database ){ is_expected.to eq Arcade::Config.database[:test] }
  end

  context "create a document type " do
    before(:all) do
      r= DB.create_type :document, 'test_document'
    end

    it "The document type is present" do
      r= DB.hierarchy(type: :document).flatten

      expect(r).to be_an Array
      expect(r).to  include 'test_document'
    end
    it "Insert a dataset" do
      r= DB.create 'test_document' ,  name: "Gugo",  bes: "Über", age: 54
      expect(r).to eq "#1:0"   # returns the rid

      rr=  DB.get r

      expect(rr).to be_a   Arcade::Basicdocument
      # rid is proper formatted
      expect(rr.rid).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      expect(rr.values).to be_a Hash
      expect(rr.values.keys.sort).to eq [:age, :bes, :name]
    end
  end
  context "create a vertex type " do
    before(:all) do
      r= DB.create_type :vertex, :test_vertex
    end
 
    it "The  vertex type is present" do
      r= DB.hierarchy( type: :vertex ).flatten
      expect(r).to be_an Array
      expect(r).to  include 'test_vertex'
    end

    it "Insert a dataset" do
      rid= DB.create 'test_vertex',  name: "Gugo",  bes: "Über", age: 54
      expect(rid).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/

      r=  DB.get rid

      expect(r).to be_an  Arcade::TestVertex
      expect(r.attributes).to be_a Hash
      expect(r.attributes.keys).to include :name      # rid is proper formatted
      expect(r.rid).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
    end
  end

  context "read a record" do
    before( :all ){ @rid=  DB.create :test_vertex, name: "parent", age: 54}
    it "retreives the correct model" do
      r =  DB.get @rid
      expect(r).to be_an Arcade::TestVertex
      expect(r.age).to eq 54
      expect(r.name).to eq 'parent'
    end
  end

  context "basic operations on an edge "  do
    before(:all) do
      DB.create_type :edge, :test_edge
    end

    it "The edge type is present in the database" do
      r= DB.hierarchy( type: :edge ).flatten
      expect(r).to be_an Array
      expect(r).to  include 'test_edge'
    end

    it "Insert an edge" do
      rid1= DB.create 'test_vertex',  name: "parent", age: 54
      rid2= DB.create 'test_vertex',  name: "child" , age: 4
      edge = DB.create_edge 'test_edge',  from: rid1,  to: rid2  # the edge ist present in the database
      puts edge.inspect
      edge.each do  |e|
        the_e =  DB.get e
        expect(the_e).to be_an  Arcade::Basicedge                   #  .. but not  at the ruby side
        ## includes system attributes
        expect(the_e.attributes).to include(:rid )
        expect(the_e.attributes).to include(:in, :out )
        # rid is proper formatted
        expect(the_e.rid).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
        # even a  basic-edge has proper in- and out-attributes
        expect(the_e.in).to eq rid2     # to    tramslates to :in
        expect(the_e.out).to eq rid1    # from  translates to :out
      end
    end

    #### THIS FAILS EVERYTIME
    it "Inserts a bunch of records and connects them with edges" do

      rid1=  DB.create 'test_vertex',  name: "parent", age: 54
      edges =  (1..500).map do |i| 
                        puts i 
                        Arcade::Api.begin_transaction DB.database
                        vertex=  DB.create 'test_vertex',  name: "child", age: i
                        edge = DB.create_edge 'test_edge',  from: rid1,  to: vertex  # the edge ist present in the database
                        Arcade::Api.commit DB.database
                       print edge 
      end
      expect(edges.size).to eq 500

      
    end
  end


end
