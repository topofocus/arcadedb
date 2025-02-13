require 'spec_helper'
require "rspec/given"
require 'database_helper'


def linear_elements start, count  #returns the edge created
	new_vertex = ->(n) { Arcade::ExtraNode.insert( note_count: n) }
	(2..count).each{ |n| start = start.assign vertex: new_vertex[n], via: Arcade::Connects }
end

RSpec.describe "Edges" do
  before( :all ) do
    connect
    db = Arcade::Init.db
 #   db.begin_transaction

    Arcade::BaseNode.create_type
    Arcade::Node.create_type
    Arcade::ExtraNode.create_type
    Arcade::Connects.create_type
  end
  after(:all) do
     db = Arcade::Init.db
     Arcade::Connects.delete all: true
     Arcade::ExtraNode.delete all: true
     Arcade::Node.delete all: true
     Arcade::BaseNode.delete all: true
     
  #   db.rollback
  end



  context " One to many connection"  do
    before(:all) do
      previous_logger_level =  Arcade::Database.logger.level
      Arcade::Database.logger.level = Logger::ERROR
      b =	 Arcade::ExtraNode.insert( extraitem: 'nucleus' )
      (1..10).map do |n| 
        new_node =  Arcade::Node.insert( item: n)
        (1..10).map{|i|	new_node.assign vertex: Arcade::Node.insert( item: new_node.item * rand(99999)), via: Arcade::Connects, attributes: { extra: true  }}
        Arcade::Connects.create from: b, to: new_node, basic: true
      end
      Arcade::Database.logger.level = previous_logger_level
    end
    it "check structure"  do
      expect( Arcade::ExtraNode.count).to eq 1
      expect( Arcade::Node.count).to eq 111
      expect( Arcade::Connects.count).to eq 110
      end
    end


    context "linear graph"  do

      before(:all) do

        previous_logger_level =  Arcade::Database.logger.level
        Arcade::Database.logger.level = Logger::ERROR
        start_node =  Arcade::ExtraNode.insert( extraitem: 'linear' )
        linear_elements start_node , 200
        Arcade::Database.logger.level = previous_logger_level
      end

      Given( :start_point ){ Arcade::ExtraNode.where(  extraitem: 'linear' ).first }
      context "traverse {n} elements" do
        Given( :all_elements ) { start_point.traverse :out, via: Arcade::Connects, depth: -1 }
        Then {  expect( all_elements.size).to eq 200 }
        Given( :hundred_elements ) { start_point.traverse :out, via: Arcade::Connects, depth: 100 }
        Then {  expect( hundred_elements.size ).to eq 100 }
      end
      context ", get decent elements of the collection"  do
        #				it{ puts "hundred_elements #{hundred_elements.to_s}" }
        #				Given( :fetch_elements ) { start_point.execute }
        #				Then {  expect( fetch_elements.size ).to eq 100 }

        Given( :fifty_elements ) { start_point.traverse :out, via: Arcade::Connects, depth: 100, start_at: 50}
        Then { expect( fifty_elements.size).to  eq 50 }
        Then { expect( fifty_elements).to  be_a Array }
        Then { expect( fifty_elements.map &:note_count ).to eq (51 .. 100).to_a }
      end
      context ",apply median to the set" do
        Given( :hundred_elements ) { start_point.traverse :out, via: Arcade::Connects, depth: 100, execute: false }
        Then { expect(hundred_elements).to be_a Arcade::Query }
        Given( :median ) do
          Arcade::Query.new from: hundred_elements,
            projection: 'median(note_count)'  ,
            where: '$depth>=50 '
        end
        Then { median.to_s == "select median(note_count) from  ( traverse out('connects') from #{start_point.rid} while $depth < 100   )  where $depth>=50  " }

        Given( :median_q ){ median.execute.first }  # result: {:"median(note_count)"=>75.5
        Then {  median_q.keys == [:"median(note_count)"] }
        Then {  expect( median_q.values).to eq [75.5] }
      end

      context "use nodes" do
        Given( :start ){ Arcade::Node.where( note_count: 67).first }
        Then { expect( start.nodes ).to be_an Array }
        Then { expect( start.nodes.first ).to be_a Arcade::ExtraNode }
        Then { expect( start.nodes.count ).to eq 2 }
      end
    end
end

