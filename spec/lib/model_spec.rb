require 'spec_helper'
require 'database_helper'
require 'rspec/given'
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
    connect
    db = Arcade::Init.db
    db.begin_transaction
    Arcade::TestDocument.create_type
    Arcade::TestDocument.delete all: true
  end
  after(:all) do
     db = Arcade::Init.db
     db.rollback
  end


  context "in situ creation of a TestDocument" do
    #  in_situ = DB.query " select from test_document order by @rid limit 1"
    #
    Given( :in_situ ){  [{ :@type=>"test_document",  :date=> Date.parse("2019-05-26"), :name=>"imwera", :age=>16}] }
   When( :model ){ in_situ.allocate_model }
   Then { model.is_a? Array }
   When( :document ){ model.first }
   Then { document.is_a? Arcade::TestDocument }
   Then { document.rid == "#0:0" }
   Then { document.name == "imwera" }
   Then { document.age == 16 }
   Then { document.date ==  Date.new( 2019,5,26 ) }

  end
  
end
