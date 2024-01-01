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
    Arcade::BaseNode.create_type
    Arcade::TestEdge.create_type
    db.begin_transaction
    Arcade::BaseNode.delete all: true
    a = Arcade::BaseNode.insert :item => "hugo"
    b = Arcade::BaseNode.insert :item => "berta"
    a.assign via: Arcade::TestEdge, vertex: b

  end
  after(:all) do
     db = Arcade::Init.db
     db.rollback
  end


  context "simple match statement" do
    #  in_situ = DB.query " select from test_document order by @rid limit 1"
    #
    Given( :simple_statement ){ Arcade::Match.new type: Arcade::BaseNode,
                                                 where: { item: 'hugo' },
                                                    as: :item  }
    Then { simple_statement.to_s == "MATCH { type: base_node, where: ( item='hugo' ), as: item } RETURN item "  }
    Then { simple_statement.execute.allocate_model.first.is_a? Arcade::BaseNode }


    Given( :match_edge ){ simple_statement.out(Arcade::TestEdge) }
    Then { match_edge.to_s == "MATCH { type: base_node, where: ( item='hugo' ), as: item }.out('test_edge') RETURN item "  }


    Given( :node_edge ){ match_edge.node( where: { item: 'berta' }) }
    Then { node_edge.to_s == "MATCH { type: base_node, where: ( item='hugo' ), as: item }.out('test_edge'){ where: ( item='berta' ) } RETURN item "  }
    Then { node_edge.execute.allocate_model.first.is_a? Arcade::BaseNode }

    ## No Match
    Given( :no_node_edge ){ match_edge.node( where: { item: 'erta' }) }
    Then { no_node_edge.execute.allocate_model == [] }
  end

  context "constucted match statements"  do
    Given( :the_first ){ Arcade::Match.new( type: Arcade::BaseNode, as: :items ).out.node.in.node(as: :name) }
    Then { the_first.to_s ==  "MATCH { type: base_node, as: items }.out(){}.in(){ as: name } RETURN items,name " }


    Given( :the_real ){ Arcade::Match.new( type: Arcade::BaseNode, where: { symbol: 'Still' } )
                                     .out( Arcade::TestEdge )
                                     .node( as: :c )
                                     .in.node( while: true , as: :o) }
    Then { the_real.to_s == "MATCH { type: base_node, where: ( symbol='Still' ) }.out('test_edge'){ as: c }.in(){ while: ( true ), as: o } RETURN c,o "}

    Given( :complete_query ){ Arcade::Query.new from: the_real.to_s, where: { "o.order_type"  => 'constructed' }, projection: 'c.@rid' }
    Then { complete_query.to_s == "select c.@rid from (MATCH { type: base_node, where: ( symbol='Still' ) }.out('test_edge'){ as: c }.in(){ while: ( true ), as: o } RETURN c,o ) where o.order_type='constructed' " }
    # thats the working order for finished trades
  end



end
