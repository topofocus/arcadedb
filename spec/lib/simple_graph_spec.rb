require 'spec_helper'
require "rspec/given"
require 'database_helper'


def linear_elements start, count  #returns the edge created

	new_vertex = ->(n) { Arcade::ExtraNode.create( note_count: n) }
#	e= Connects.create from: start, to: new_vertex[1]
#	(2..count).each do |m|
#		e= Connects.create from: e.first.in , to: new_vertex[m]
#	end
	(2..count).each{ |n| start = start.assign vertex: new_vertex[n], via: Arcade::Connects }
end

RSpec.describe "Edges" do
  before( :all ) do
    clear_arcade
    DB = Arcade::Database.new :test

    Arcade::Vertex.create_type :base_node
    Arcade::Vertex.create_type :node
		Arcade::Node.create_type :extra_node
    Arcade::Edge.create_type :connects
 #   c.uniq_index
  end



  context "Connect some vertices", focus: true do
    before(:all) do
      b =	 Arcade::BaseNode.create( item: 'b' )
      (1..10).map do |n| 
        new_node =  Arcade::Node.create( item: n)
        (1..10).map{|i|	new_node.assign vertex: Arcade::ExtraNode.create( item: new_node.item * rand(99999)), via: Arcade::Connects, attributes: { extra: true  }}
        Arcade::Connects.create from: b, to: new_node, basic: true
      end
    end
    it "check structure"  do
      expect( Arcade::BaseNode.count).to eq 1
      expect( Arcade::Node.count).to eq 110
      expect( Arcade::ExtraNode.count).to eq 100
      expect( Arcade::Connects.count).to eq 110
    end
    it  "has valid edges" do
      result =  Arcade::BaseNode.nodes(:out, where: { item: 'b' }).first
      puts result.inspect
      expect( result ).to have( 10 ).items
      result.each{|y| expect( y.to be_a Arcade::Node )}
      (1..10).each do | n |
        the_node =   Arcade::Node.where( item: n ).first 
        expect( the_node.in(/connects/).out ).to eq Arcade::BasiccNode.where(item: 'b')
        expect( the_node.out(Arcade::Connects)).to have(10).items 
      end
    end
  end

  context " One to many connection"  do

    it "create the structue" do
      central_node =  Arcade::BaseNode.create( item: 'center' ) #
      #central_node =  Arcade::Node.create item: 'center'
      peripherie_nodes =  (1..20).map{ |y|  Arcade::ExtraNode.create item: y }
      Arcade::Connects.create from: central_node, to: peripherie_nodes
      expect(Arcade::Connects.count).to be > 19
      expect(central_node.out_connects.count).to be >19
    end
  end


		context "linear graph"  do

			before(:all) do
				start_node =  Arcade::BaseNode.create( item: 'l' ) 
				linear_elements start_node , 200
			end

			Given( :start_point ){ Arcade::BaseNode.where(  item: 'l' ).last }
			context "traverse {n} elements" do
				Given( :all_elements ) { start_point.traverse :out, via: /con/, depth: -1 }
				Then {  expect( all_elements.size).to eq 200 }
				Given( :hundred_elements ) { start_point.traverse :out, via: /con/, depth: 100 }
				Then {  expect( hundred_elements.size ).to eq 100 }
			end

			context ", get decent elements of the collection"  do
				Given( :hundred_elements ) { start_point.traverse :out, via: /con/, depth: 100, execute: false }
				Then { expect(hundred_elements).to be_a OrientSupport::OrientQuery }
#				it{ puts "hundred_elements #{hundred_elements.to_s}" }
#				Given( :fetch_elements ) { start_point.execute }
#				Then {  expect( fetch_elements.size ).to eq 100 }  

				Given( :fifty_elements ) { start_point.traverse :out, via: /con/, depth: 100, start_at: 50}
				Then { expect( fifty_elements.size).to  eq 50 }
				Then { expect( fifty_elements).to  be_a Array }
				#Then { expect( fifty_elements).to  be_a OrientSupport::Array }
				it{ puts "hundred_elements #{fifty_elements.class}" }
				Then { expect( fifty_elements.note_count ).to eq (51 .. 100).to_a }

				context "and apply median to the set" do
					Given( :median ) do 
						Arcade::Query.new from: hundred_elements, 
							projection: 'median(note_count)'  , 
							where: '$depth>=50 '
					end
					Then { median.to_s.ex_rid == "select median(note_count) from  ( traverse  outE('connects').in  from * while $depth < 100   )  where $depth>=50  " }

					Given( :median_q ){ @db.execute{ median.to_s }.first }
					Then {  median_q.keys == ["median(note_count)".to_sym] }
					Then {  expect( median_q.values).to eq [75.5] }
				end

				context "use nodes" do
					Given( :start ){ Node.where( note_count: 67).first }
					Then { expect( start.nodes ).to be_an Array }
					Then { expect( start.nodes.first ).to be_a Arcade::ExtraNode }
					Then { expect( start.nodes.count ).to eq 1 }
				end
		end
	end
end


#### match ---> v3 --->  return expand(x) to operate on the expanded version on the resultset
