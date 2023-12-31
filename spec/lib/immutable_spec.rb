require 'spec_helper'
require 'database_helper'
require 'rspec/given'
###
# ArcadeDB types can be declared as immutable
# Then only queries and insert-operations are possible
#
RSpec.describe Arcade::Base do
  before(:all) do
    connect
    db = Arcade::Init.db
    My::ReadOnly.create_type
    db.begin_transaction
    My::ReadOnly.insert node: 1

  end
  after(:all) do
     db = Arcade::Init.db
     db.rollback
  end



  context "Insert another record is possible" do

    before(:all){ My::ReadOnly.insert node: 2 }
    Given( :the_type  ){ My::ReadOnly }
    Then { the_type.count == 2  }
    Then { the_type.where( node: 2).first.node == 2 }

  end

  context "Try to modify a record" do

    before(:all){ My::ReadOnly.insert node: 3 }
    Given( :the_record ){ My::ReadOnly.find node: 3 }
    Then { expect { the_record.update node: 5 }.to raise_error  Arcade::ImmutableError }
    Then { expect { the_record.delete }.to raise_error  Arcade::ImmutableError }
    Then { expect { the_record.upsert }.to raise_error  Arcade::ImmutableError }

  end

  context "modify the type via class methods is still possible" do

    Given( :the_type  ){ My::ReadOnly }
    Then{ expect{  the_type.delete node: 3  }.to change { the_type.count }.by(-1) }

  end

end
