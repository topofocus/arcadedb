require 'spec_helper'
require 'database_helper'

require 'rspec/given'

RSpec.describe Arcade::Revision do
  before(:all) do
    connect
    db = Arcade::Init.db
  #  db.begin_transaction
    My::NamesR.create_type
    Arcade::RevisionRecord.create_type
    My::NamesR.delete all: true
  end
  after(:all) do
     db = Arcade::Init.db
   #  db.rollback
  end

  context "create a revision record" do
    Given( :revision ){  Arcade::RevisionRecord.create user: 'test', action: "Record initiated" }
    Then { revision.is_a? Arcade::RevisionRecord }
    Then { revision.user == 'test' }
    Then { revision.rid == '#0:0' }
  end

  context "Insert a revision backed record"  do
    before(:all) do
      My::NamesR.insert  name: "testperson", age: 25
    end

    Given( :testperson ){ My::NamesR.first }
    Then { testperson.name == 'testperson' }
    Then { testperson.protocol.is_a? Array }
    Then { testperson.protocol.first.is_a?  Arcade::RevisionRecord }
    Then { testperson.protocol.first.action == "Record initiated" }
  end

  context "Update a revision backed record"  do
    before(:all) do
     i= My::NamesR.insert  name: "testperson2", age: 30
     i.update( town: "Capetown"){ "forgot to insert hometown" }
    end
    Given( :updatedperson ){ My::NamesR.find name: 'testperson2'}
    Then { updatedperson.town == 'Capetown' }
    Then { updatedperson.protocol.size == 2 }
    Then { updatedperson.protocol.last.action == "forgot to insert hometown" }
    Then { updatedperson.protocol.last.fields == { town: nil } }

  end
end
