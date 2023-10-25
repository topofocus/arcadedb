require 'spec_helper'

def clear_arcade
  #  delete testdatabase and restore it
  databases =  Arcade::Api.databases
  if  databases.include?(Arcade::Config.database[:test])
  Arcade::Api.drop_database Arcade::Config.database[:test] 
  end
  Arcade::Api.create_database Arcade::Config.database[:test]
  Arcade::Api.create_database Arcade::Config.database[:test]
end


RSpec.describe Arcade::Api do
  context "Arcade returns present databases"  do
    subject {  Arcade::Api.databases  }
    it { is_expected.to be_a Array }
  end

  context "clear test database" do
    clear_arcade
    subject {  Arcade::Api.databases  }
    it { is_expected.to be_a Array }
    it { is_expected.to include  Arcade::Config.database[:test] }

  end
  context "create a document type " do
    before(:all) do
      r= Arcade::Api.execute( Arcade::Config.database[:test]) { "create document type test_document" } 
      expect( r.size ).to eq 1
      expect( r.first ).to be_a Hash
      expect( r.first.keys.sort).to eq [:operation, :typeName]
      expect( r.first[:typeName] ).to eq "test_document"
      expect( r.first[:operation] ).to eq "create document type"
    end

    it "The document type is present" do
      # fetch list of types
     r= Arcade::Api.execute( Arcade::Config.database[:test]){  'select from schema:types' }.first
      #=> {"indexes"=>[], "parentTypes"=>[], "name"=>"test_document", "type"=>"document", "properties"=>[]}

      expect( r ).to be_a  Hash
      expect( r[:name] ).to eq 'test_document'
      expect( r[:type] ).to eq 'document'
      expect( r[:properties] ).to be_empty
    end

    it "Add a property and an Index"   do
      Arcade::Api.execute( Arcade::Config.database[:test]) { "create document type my_names" }
      expect(  Arcade::Api.property( Arcade::Config.database[:test] , 'my_names',
                                     name: :string, age: :integer)).to  be_truthy
      expect(  Arcade::Api.index( Arcade::Config.database[:test] , 'my_names',
                                     :age, :unique)).to be_truthy
    end
    it "Insert a dataset"  do
      r= Arcade::Api.create_document  Arcade::Config.database[:test], 'test_document' ,  name: "Gugo",  bes: "Über", age: 54.3
      expect(r).to eq "#1:0"   # returns the rid

      r=  Arcade::Api.get_record Arcade::Config.database[:test], "#1:0"

      expect(r).to be_an Hash
      ## includes system attributes
      expect(r.keys).to include(:"@rid", :"@type", :"@cat" )
      # rid is proper formated
      expect(r[:"@rid"]).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      # includes  fields from »create document call« and proper values
      expect(r.keys).to include( :name, :bes, :age )
      expect(r[:age]).to eq 54.3
      expect(r[:bes]).to eq "Über"
      #   {"bes"=>"Über", "@rid"=>"#1:0", "@type"=>"test_document", "name"=>"Gugo", "@cat"=>"d", "age"=>54.3}
    end

    it "drop type" do
      Arcade::Api.execute( Arcade::Config.database[:test]) { "create document type drop_document" }
      r= Arcade::Api.execute( Arcade::Config.database[:test]){  'select from schema:types' }.first
      expect( r[:name] ).to eq 'drop_document'
      Arcade::Api.execute( Arcade::Config.database[:test]){ "drop type drop_document if exists" }
      r= Arcade::Api.execute( Arcade::Config.database[:test]){  'select from schema:types' }.first
      expect( r[:name] ).not_to eq 'drop_document'
    end
  end
  context "create a vertex type " do
    before(:all){ Arcade::Api.execute( Arcade::Config.database[:test]) { "create vertex type test_vertex" } }

    it "The  vertex type is present" do
      # fetch list of types
      r= Arcade::Api.execute( Arcade::Config.database[:test]){  'select from schema:types' }
     #[ {"indexes"=>[], "parentTypes"=>[], "name"=>"test_document", "type"=>"document", "properties"=>[]},
     # {"indexes"=>[], "parentTypes"=>[], "name"=>"test_vertex", "type"=>"vertex", "properties"=>[]}]

      expect(r).to be_an Array
      expect(r.last).to be_a  Hash
      expect(r.last[:name]).to eq 'test_vertex'
      expect(r.last[:type]).to eq 'vertex'
      expect(r.last[:properties]).to be_empty
    end
    it "Insert a dataset" do
      rid= Arcade::Api.create_document  Arcade::Config.database[:test], 'test_vertex',  name: "Gugo",  bes: "Über", age: 54.3
      expect(rid).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/

      r=  Arcade::Api.get_record Arcade::Config.database[:test], rid

      puts "vertex: #{r}"
      expect(r).to be_an Hash
      ## includes system attributes
      expect(r.keys).to include(:"@rid",:"@type", :"@cat" )
      expect(r.keys).to include(:"@in", :"@out" )
      # rid is proper formated
      expect(r[:"@rid"]).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      # includes  fields from »create document call« and proper values
      expect(r.keys).to include( :name, :bes, :age )
      expect(r[:age]).to eq 54.3
      expect(r[:bes]).to eq "Über"
      #  {"@out"=>0, "bes"=>"Über", "@rid"=>"#9:0", "@in"=>0, "@type"=>"test_vertex", "name"=>"Gugo", "@cat"=>"v", "age"=>54.3}
    end
  end
  context "create a edge type "   do
    before(:all){ Arcade::Api.execute( Arcade::Config.database[:test]) { "CREATE EDGE TYPE test_edge" } }

    it "The edge type is present" do
      # fetch list of types
      r= Arcade::Api.execute( Arcade::Config.database[:test]){  'select from schema:types' }
      #[{"indexes"=>[], "parentTypes"=>[], "name"=>"test_document", "type"=>"document", "properties"=>[]},
      # {"indexes"=>[], "parentTypes"=>[], "name"=>"test_edge", "type"=>"edge", "properties"=>[]},
      # {"indexes"=>[], "parentTypes"=>[], "name"=>"test_vertex", "type"=>"vertex", "properties"=>[]}] 
      r =  r.find{|y| y[:name] == 'test_edge'}

      expect(r).to be_a  Hash
      expect(r[:name]).to eq 'test_edge'
      expect(r[:type]).to eq 'edge'
      expect(r[:properties]).to be_empty
      expect(r[:indexes]).to be_empty
    end
    it "Insert an edge" do
      rid1= Arcade::Api.create_document  Arcade::Config.database[:test], 'test_vertex',  name: "parent", age: 54.3
      rid2= Arcade::Api.create_document  Arcade::Config.database[:test], 'test_vertex',  name: "child" , age: 4.3
      edge= Arcade::Api.execute( Arcade::Config.database[:test] ){ "create edge test_edge from #{rid1} to #{rid2}"  }
      puts "edge: #{edge}"
      r =  edge.first
      expect(r).to be_an Hash
      ## includes system attributes
      expect(r.keys).to include(:"@rid", :"@type", :"@cat" )
      expect(r.keys).to include(:"@in", :"@out" )
      # rid is proper formated
      expect(r[:"@rid"]).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      # includes  fields from »create document call« and proper values
    end
  end
end
