require 'spec_helper'
require 'database_helper'

require 'rspec/given'
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
    connect
    db = Arcade::Init.db
    db.begin_transaction
    db.transmit{ "DROP TYPE test_document IF EXISTS" }
    db.transmit{ "DROP TYPE dep_test_doc  IF EXISTS" }
    Arcade::TestDocument.create_type
    Arcade::DepTestDoc.create_type
  end
  after(:all) do
     db = Arcade::Init.db
     db.rollback
  end


  context "check hierarchy" do
    Given( :databases ) { Arcade::Init.db.hierarchy  type: :document }
    Then{ expect( databases.flatten ).to include 'test_document' }
  end
  context "check indexes" do
    Given( :indexes ){ Arcade::Init.db.indexes.find{|x| x[:name] =~ /test_document/} }
    Then { indexes.is_a? Hash }
    And  { indexes[:name] == "test_document[name,age]" }
    # check if the declared properties are set
    And { indexes[:properties] == ["name","age"] }
  end
  context "Add a record" do
   it "create a document" do
      Arcade::TestDocument.delete all: true
      document =  Arcade::TestDocument.insert name: 'Hugo', age: 40, item: 1
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
      d =  Arcade::TestDocument.update set: { name: 'Zwerg', age: 70, item: 5}, where: { name: 'Z' }
      expect( d ).to be_a Array
      expect( d.size ).to eq 0
      d =  Arcade::TestDocument.update! set: { name: 'Zwerg', age: 70, item: 5}, where: { name: 'Z' }
      expect( d ).to be_a Integer
      expect( d ).to eq 0
      d =  Arcade::TestDocument.update set: { name: 'Zwerg', age: 60, item: 7}, where: { name: 'Zwerg' }
      expect( d ).to be_a Array
      expect( d.size ).to eq 1
      document = d[0]
      expect( document ).to be_a Arcade::TestDocument
      expect( document.rid ).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      expect( document.name ).to eq "Zwerg"
      expect( document.age ).to eq 60
      expect( document.item ).to eq 7
      expect( Arcade::TestDocument.count ).to eq 2
#      puts Arcade::TestDocument.all.map &:to_human
      d =  Arcade::TestDocument.update! set: { name: 'Zwergen'}, where: { item: 7 }
#      puts Arcade::TestDocument.all.map &:to_human
      expect( d ).to be_a Integer
      expect( d ).to eq 1
    end
   it "add a record through inheritance" do
     # insert returns a document
      document =  Arcade::DepTestDoc.insert name: 'HugoTester', age: 140, item: 1
      expect( document ).to be_a Arcade::TestDocument
      expect( document.rid ).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      expect( document.name ).to eq "HugoTester"
      expect( document.age ).to eq 140
      expect( document.item ).to eq 1
      expect( Arcade::TestDocument.count ).to eq 3
      expect( Arcade::DepTestDoc.count ).to eq 1    #  Inheritance works
    end

   it "select a record " do   # where returns an Array, even if only one record is  selected
      rid =  Arcade::DepTestDoc.create name: 'BertaTester', age: 40, item: 6
      expect(  Arcade::DepTestDoc.where( item: 6 )&.first ).to eq rid
      expect(  Arcade::DepTestDoc.where( name: 'BertaTester' ) &.first ).to eq rid
      expect(  Arcade::DepTestDoc.where( "name like \"BertaTester\" ") &.first ).to eq rid
   end


   it " Add a link  to the document" do
      primary_document =  Arcade::TestDocument.insert name: 'Fred', age: 40, item: 4
      dependend_document =  Arcade::TestDocument.insert name: 'Berta', age: 50, item: 5
      modified_document = primary_document.update dep: dependend_document
      expect( modified_document.dep ).to eq dependend_document




   end




  end
end
