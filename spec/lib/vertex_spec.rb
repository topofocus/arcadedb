
require 'spec_helper'
require 'rspec/given'

require 'database_helper'

# create a star
def create_structure from
			if from.edges.empty?
				vertices =  (1..10).map{|y| My::V2.create node: y}
				other_vertices =  (1..10).map{|y| My::V3.create node: y}

        My::E2.create from: from, to: vertices
				My::E3.create from: from, to: other_vertices
			end
			  # return first node
				from
end

def linear_elements start, count  #returns the edge created

	new_vertex = ->(n) {  My::V2.create( note_count: n)}
	#starte.assign vertex: new_vertex[1], via: E2
#  Arcade::Database.logger.level=2
	(2..count).each do |m|
		start = start.assign vertex: new_vertex[m], via: My::E2
	end
#  Arcade::Database.logger.level=1
end
#  needs work to realize asynchronically creation of structures
def threaded_creation data
	th = []
#	Arcade::Database.logger.level=2
	My::V2.delete all: true
	data.map do |d|
		th << Thread.new do
			My::V2.create data: d
		end
	end
	th.each &:join # wait til all threads are finished
#	Arcade::Database.logger.level=1
  My::V2.count # return value
end

RSpec.describe Arcade::Vertex do
  before(:all) do
    clear_arcade
    DB = Arcade::Database.new :test
    My::V2.create_type
    My::V3.create_type
    My::E2.create_type
    My::E3.create_type
  end
	describe "CRUD", focus: true  do
		Given( :the_vertex ){ My::V2.create a: "a", b: 2, c: [1,2,3] , d: {a: 'b'}}
		context " create" do
      it { puts the_vertex.inspect }
			Then { expect( the_vertex.rid).to match /^#[0-9]*:[0-9]*/   }
		end
		context " read" do
			Given( :read_vertex ){ the_vertex.rid.expand }
			Then { expect(read_vertex.object_id).not_to eq the_vertex.object_id}
      Then { expect(read_vertex.invariant_attributes).to eq the_vertex.invariant_attributes }
		end
		context " update" do
			Given( :updated_vertex ){ the_vertex.update a: 'c' }
			Then { expect(updated_vertex.a).to eq 'c' }
		end
		context "delete" do
			it "deletes the vertex" do
				my_vertex =  My::V2.where a: 'c'
				expect(my_vertex).to be_a  My::V2
				expect{ my_vertex.delete }.to change{ My::V2.count }.by -1
			end
		end
  end

	describe "creating a sample graph"  do
   Given( :the_node ){ create_structure( My::V1.upsert( where:{ item: 1 }).first ) }
   # Then{ expect( the_node.to_human ).to match /out: {E2=>10, E3=>10}, item : 1>/ }
		Then{ the_node.edges( :out ).size ==  20 }
		Then{ the_node.edges( :in ).empty? }
	  context "Analysing Edges" do
			Then{ the_node.edges( via: My::E2 ).size == 10 }
			Then{ the_node.edges( via: My::E3 ).size == 10 }
			Then{ the_node.edges( :in, via: My::E2 ).empty? }
			Then{ the_node.edges( /e/ ).size ==  20 }
		end
		context "simulating nodes with edges" do
			Given( :the_edges ){ the_node.edges( :out, via: My::E2  ) }
			Then{ the_edges.is_a? Array }
      Then{ expect( the_edges.map{|x| x.in.expand }.map( &:node ).sort ).to eq [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]  }
      Then{ the_edges.map{|x| x.in.expand }.map( &:node)  == the_node.nodes( via: My::E2 ).map( &:node )  }
		end
		context "Analysing adjacent nodes" do
			Given( :the_nodes ){ the_node.nodes via: My::E3 }
#			Then{ the_nodes.map( &:class ).uniq == [My::V3] }   ## classes don't respond to uniq  (eq? is not defined)
			Then{ the_nodes.size == 10 }
		end
	end

	describe "analyse of vertex connections" do
		Given( :the_vertex ){ My::V2.where( node: 4 ).first }
		Given( :the_edges  ) { the_vertex.edges }
		Then { expect( the_edges).to be_a Array }
		Then { the_edges.each{|e| expect( e.rid).to match /^#[0-9]*:[0-9]*/ } }

#		context "named edges are Edge-Instances by default" do #  pending: Named edges are not implmeentexd (yet)
#			Given( :named_edge ){ the_vertex.in_e2 }
#			Then { expect(named_edge).to be_a Array  }
#			Then { named_edge.each{|e| expect( e).to be_a E } }
#		end
	end

	describe "linear graph"do
		before(:all) do
      start_node =   My::V1.upsert( where:{ item: 'l'} ).first
				linear_elements( start_node , 200) if start_node.edges.empty?
		end

	  context "the linear graph" do
      Given( :start_point ){  My::V1.upsert( where:{ item: 'l'}).first }
			Given( :all_elements ) { start_point.traverse :out, via: My::E2, depth: -1 }
				Then {  expect( all_elements.size).to eq 200 }
		end
	end

	# describe "threaded creation",  pending: "not implemented jet" do
	#	  Given( :the_raw_data ){ (1 .. 10000).map{ |y|   Math.sin(y) } }
	#	 Then { expect(the_raw_data.size).to eq 10000 }

	#	 Given( :v3_count  ) { threaded_creation the_raw_data }


	#	 Then {  expect(v3_count).to eq 10000 }

	# end
end
