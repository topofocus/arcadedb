require 'spec_helper'
require 'database_helper'
###
# The model directory  `spec/model` contains some sample files
# #
# These are used in the following tests
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
    Arcade::TestDocument.create_type
  end


  context "CRUD" do     ##  unfinised
    it  "create a document" do
      document =  Arcade::TestDocument.create name: 'Hugo', age: 40
      expect( document ).to be_a Arcade::TestDocument
      expect( document.rid ).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      expect( document.name ).to eq "Hugo"
      expect( document.age ).to eq 40
      expect( Arcade::TestDocument.count ).to eq 1
    end

    it "try to create a document with constrains" do  
      document =  Arcade::TestDocument.create name: 'Hugo', age: '40'

      expect( Arcade::TestDocument.count ).to eq 1
    end

    it "Use schemaless properties" do
      document =  Arcade::TestDocument.create name: 'Hugo', age: 60,  city: 'London'
      expect( Arcade::TestDocument.count ).to eq 2
      expect( document.city ).to be_a String
      expect( document.values ).to include  city: 'London' 
      expect( document.name ).to eq "Hugo"
      expect( document.age ).to eq 60


    end

    it "read a document" do
      the_document =  Arcade::TestDocument.last
      expect( the_document ).to be_a Arcade::TestDocument
      expect( the_document.name ).to be_a String
      expect( the_document.city ).to be_a String
    end
  end
  
end
