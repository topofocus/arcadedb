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
    Arcade::Vertex.create_type  Arcade::BaseNode
    Arcade::Vertex.create_type Arcade::Node
    Arcade::Node.create_type  Arcade::ExtraNode
    Arcade::Edge.create_type Arcade::Connects
  end


  context "check environment" do
    subject { DB.hierarchy }
    its(:first) { is_expected.to eq ['base_node'] }
    ## Detect Inheritance 
    its(:last)  { is_expected.to eq ['node', 'extra_node'] }
  end

  context "check inheritance" do
   it "create a document" do
      document =  Arcade::ExtraNode.create name: 'Hugo', age: 40, item: 1
      expect( document ).to be_a Arcade::ExtraNode
      expect( document.rid ).to  match /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      expect( document.name ).to eq "Hugo"
      expect( document.age ).to eq 40
      expect( document.item ).to eq 1 
      expect( Arcade::ExtraNode.count ).to eq 1
      expect( Arcade::Node.count ).to eq 1
    end
  end
end
