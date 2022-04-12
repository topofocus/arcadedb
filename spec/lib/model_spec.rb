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
    DB.create_type :document, :test_document
  end

  context "CRUD" do
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

  end
  
end
