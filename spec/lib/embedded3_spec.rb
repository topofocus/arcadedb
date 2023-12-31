require 'spec_helper'
require 'database_helper'
require 'rspec/given'
###
# The model directory  `spec/model` contains some sample files
# #
# These are used in the following tests
#
RSpec.describe Arcade::Vertex do
  before(:all) do
    connect
    db = Arcade::Init.db
    My::V1.create_type
    My::Alist.create_type
    My::Aset.create_type
    db.begin_transaction
    My::V1.delete all: true
    My::Alist.delete all: true
    My::Aset.delete all: true

  end
  after(:all) do
     db = Arcade::Init.db
     db.rollback
  end

  context "create nodes"  do
    before(:all) do
      (1..10).each{|i| My::V1.insert node: i }
    end

      Given( :nodes ){ My::V1.all }
    Then { nodes.is_a? Array }
    Then { nodes.count == 10 }
    Then { My::V1.find( i: 1) == My::V1.where( i: 1 ).first  }
  end

  context "insert List-elements (auto modus)" do
    before(:all) do
      n =  My::V1.insert i: 11
      (1..20).each{|i| n.update_list :c, { x: i, y: i**2 } }
    end

    Given( :the_node ){ My::V1.find i: 11  }
    Then { the_node.c.is_a? Array }
    Then { the_node.c.size == 20 }

  end
  context "insert List-elements (first modus)" do
    before(:all) do
      n =  My::V1.insert i: 12
      (1..20).each{|i| n.update_list :c, { x: i, y: i**2 }, modus: :first }
    end

    Given( :the_node ){ My::V1.find i: 12  }
    Then { the_node.c.is_a? Array }
    Then { the_node.c.size == 1 }

  end
  context "insert List-elements (append modus)" do
    # append inserts the provided hash
    before(:all) do
      n =  My::V1.insert i: 13
      (1..20).each{|i| n.update_list :c, { x: i, y: i**2 }, modus: :append }
    end

    Given( :the_node ){ My::V1.find i: 13  }
    Then { the_node.c.is_a? Hash }
    Then { the_node.c[:x] == 20 }
  end
  context "insert List-elements (mixed modus)" do
    before(:all) do
      n =  My::V1.insert i: 14
      n.update_list :c, { x: 0, y: 0  }, modus: :first
      (1..20).each{|i| n.update_list :c, { x: i, y: i**2 }, modus: :append }
    end

    Given( :the_node ){ My::V1.find i: 14  }
    Then { the_node.c.is_a? Array }
    Then { the_node.c.size == 21 }
  end
  context "insert List-elements ( preferred modus)" do
    # initialize the record with an empty array
    before(:all) do
      n =  My::V1.insert i: 15, c: []
      (1..20).each{|i| n.update_list :c, { x: i, y: i**2 }, modus: :append }
    end

    Given( :the_node ){ My::V1.find i: 15  }
    Then { the_node.c.is_a? Array }
    Then { the_node.c.size == 20 }
  end
end

