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
    connect
    db = Arcade::Init.db
    db.begin_transaction
    Arcade::BaseNode.create_type
    Arcade::ExtraNode.create_type
  end
  after(:all) do
     db = Arcade::Init.db
     db.rollback
  end


  context "check environment" do
    subject { Arcade::Init.db.hierarchy }
    its(:first) { is_expected.to eq ['base_node'] }
    ## Detect Inheritance 
    its(:last)  { is_expected.to eq ['node', 'extra_node'] }
  end

  context "check inheritance" do
   it "create a node" do
      node =  Arcade::ExtraNode.insert name: 'Hugo', age: 40, item: 1
      expect( node ).to be_a Arcade::ExtraNode
      expect( node.rid ).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      expect( node.name ).to eq "Hugo"
      expect( node.age ).to eq 40
      expect( node.item ).to eq 1 
      expect( Arcade::ExtraNode.count ).to eq 1
      expect( Arcade::Node.count ).to eq 1
    end
  end
end
