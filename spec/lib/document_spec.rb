require 'spec_helper'
require 'database_helper'
###
# The model directory  `spec/model` contains sample files
# #
##  arcade/test_document.rb
##  arcade/dep_test_dec.rb
#
#
#
RSpec.describe Arcade::Document do
  before(:all) do
    clear_arcade
    DB = Arcade::Database.new :test
    Arcade::DepTestDoc.create_type
  end


  context "check hierarchy" do
    subject { DB.hierarchy  type: :document }
    its(:first) { is_expected.to include 'test_document' }
  end
  context "check indexes" do
    subject{ DB.indexes }
    ###
    ## expected output: {:unique=>false, :name=>"test_document[name]",:typeName=>"test_document",:automatic=>true, :type=>"LSM_TREE",:properties=>["name"]}
    # check if the index ist applied
    its( :first ){ is_expected.to be_a Hash }
    it{ expect( subject.first[:name]).to eq "test_document[name,age]" }
    # check if the declared properties are set
    it{ expect( subject.first[:properties]).to eq ["name","age"] }
  end
  context "Add a record" do
   it "create a document" do
      document =  Arcade::TestDocument.create name: 'Hugo', age: 40, item: 1
      expect( document ).to be_a Arcade::TestDocument
      expect( document.rid ).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      expect( document.name ).to eq "Hugo"
      expect( document.age ).to eq 40
      expect( document.item ).to eq 1
      expect( Arcade::TestDocument.count ).to eq 1
    end

   it "create through upsert" do
      d =  Arcade::TestDocument.upsert set:{ name: 'Zwerg', age: 70, item: 5}, where: { name: 'Zwerg' }
      expect( d ).to be_a Array
      expect( d.size ).to eq 1
      document = d[0]
      expect( document ).to be_a Arcade::TestDocument
      expect( document.rid ).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      expect( document.name ).to eq "Zwerg"
      expect( document.age ).to eq 70
      expect( document.item ).to eq 5
      expect( Arcade::TestDocument.count ).to eq 2
    end

   it "update an document" do
      d =  Arcade::TestDocument.update set:{ name: 'Zwerg', age: 70, item: 5}, where: { name: 'Z' }
      expect( d ).to be_a Array
      expect( d.size ).to eq 0
      d =  Arcade::TestDocument.update! set:{ name: 'Zwerg', age: 70, item: 5}, where: { name: 'Z' }
      expect( d ).to be_a Integer
      expect( d ).to eq 0
      d =  Arcade::TestDocument.update set:{ name: 'Zwerg', age: 60, item: 7}, where: { name: 'Zwerg' }
      expect( d ).to be_a Array
      expect( d.size ).to eq 1
      document = d[0]
      expect( document ).to be_a Arcade::TestDocument
      expect( document.rid ).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      expect( document.name ).to eq "Zwerg"
      expect( document.age ).to eq 60
      expect( document.item ).to eq 7
      expect( Arcade::TestDocument.count ).to eq 2
      d =  Arcade::TestDocument.update! set:{ name: 'Zwerg', age: 60, item: 7}, where: { name: 'Zwerg' }
      puts d.inspect
      expect( d ).to be_a Integer
      expect( d ).to eq 1
    end
   it "add a record through inheritance" do
      document =  Arcade::DepTestDoc.create name: 'HugoTester', age: 140, item: 1
      expect( document ).to be_a Arcade::TestDocument
      expect( document.rid ).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      expect( document.name ).to eq "HugoTester"
      expect( document.age ).to eq 140
      expect( document.item ).to eq 1
      expect( Arcade::TestDocument.count ).to eq 3
      expect( Arcade::DepTestDoc.count ).to eq 1    #  Inheritance works
    end

   it "select a record " do   # where returns an Array, even if only one record is  selected
      document =  Arcade::DepTestDoc.create name: 'BertaTester', age: 40, item: 6
      expect(  Arcade::DepTestDoc.where( item: 6 )&.first ).to eq document
      expect(  Arcade::DepTestDoc.where( name: 'BertaTester' ) &.first ).to eq document
      expect(  Arcade::DepTestDoc.where( "name like \"BertaTester\" ") &.first ).to eq document
   end 

  end
end
