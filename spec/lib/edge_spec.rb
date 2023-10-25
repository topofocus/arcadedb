require 'spec_helper'
require 'database_helper'
#require 'model_helper'
require 'rspec/given'

include Arcade

RSpec.describe Arcade::Query do
  before( :all ) do
    clear_arcade
    DB= Arcade::Database.new :test
    Arcade::Node.create_type
    Arcade::UniqEdge.create_type
  end # before


 context "non unique edges"  do
  Given!( :the_node ){  Node.insert item:rand(76) }
  Then { the_node.is_a? Arcade::Node }
  Then { the_node.item.is_a? Integer }

  Given { the_node.assign via: UniqEdge, vertex: Node.insert( item: rand(999) ) }
  Given { the_node.assign via: UniqEdge, vertex: Node.insert( item: rand(999) ) }
  Then  { the_node.refresh.out.size == 2 }
 end
 context "unique edges" do
  Given!( :the_node ){  Node.insert item:rand(7) }
  Given!( :the_node1 ){  Node.insert item: 999 }

  Given { the_node.assign via: UniqEdge, vertex: the_node1 }
  Given!( :new_node ) { the_node.assign via: UniqEdge, vertex: the_node1 }
  Then  { the_node.refresh.out.size == 1 }
  Then  { new_node == the_node1 }
 end
end
