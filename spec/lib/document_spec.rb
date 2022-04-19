require 'spec_helper'
require 'database_helper'
###
# The model directory  `spec/model` contains some sample files
# #
# vertex -> BasicNode 
# vertex -> Node  -> ExtraNode
# edge -> CONNECTS
#
#
# In projects, define the model files and include them  via zeitwerk
#
#    loader = Zeitwerk::Loader.new
#    loader.push_dir("#{__dir__}/model")
#    loader.setup
#
#
RSpec.describe Arcade::Document do
  before(:all) do
    clear_arcade
    DB = Arcade::Database.new :test
    Arcade::Document.create_type  Arcade::TestDocument
  end


  context "check environment" do
    subject { DB.hierarchy  type: :document }
    its(:first) { is_expected.to eq ['test_document'] }
    # check if the index ist applied
    it{ expect( DB.types.first[:indexes].first[:name]).to eq "test_document[name]" }
    # check if the declared properties are set
    it{ expect( DB.types.first[:properties].map{|y| y[:name]} ).to eq ["age", "name"] }
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
      expect( d ).to be_a Integer
      expect( d ).to eq 1
    end


  end
end
