require 'spec_helper'
require 'database_helper'
#require 'model_helper'
require 'rspec/given'

include Arcade

RSpec.describe Arcade::Query do
  before( :all ) do
    connect
    db = Arcade::Init.db
    db.begin_transaction
    Arcade::TestQuery.create_type
    Arcade::TestDocument.create_type
#    @db.create_class 'Openinterest'
#    @db.create_class "match_query"
  end # before
  after(:all) do
     db = Arcade::Init.db
     db.rollback
  end


 context "Simple Hash" do
  Given( :the_document ){  TestDocument.insert name:"hugi", age: rand(99) }
  Then { the_document.is_a? Arcade::TestDocument }
  Then { the_document.name == 'hugi' }

  Given{ Arcade::Init.db.transmit{ " update #{the_document.rid} set d= MAP( 'testkey', 'testvalue' ) " } ; the_document.refresh}
  Given{  Arcade::Init.db.transmit{ " update #{the_document.rid} set d.testkey2 = 'testvalue2' " } }
  Given{ Arcade::Init.db.transmit{ " update #{the_document.rid} set d += ['testkey3', 'testvalue3' ]" } }
  Given{ Arcade::Init.db.transmit{ " update #{the_document.rid} set d += {'testkey3': 'testvalue3' }" } }

  Then { the_document.refresh.d == { testkey: 'testvalue',  :testkey2 => 'testvalue2', :'testkey3' =>'testvalue3' }  }
 end
 context "Nested  Hash" do
  Given!( :the_document ){  TestDocument.insert name:"Nesti", age: rand(99) }
  Then { the_document.is_a? Arcade::TestDocument }
  Then { the_document.name == 'Nesti' }

  Given{ Arcade::Init.db.transmit{ " update #{the_document.rid} set d = MAP ( 'testkey', { 'nested_key': 'nested_value' } ) "  } }
  Then {  expect( the_document.refresh.d).to be_a Hash }
  Given{  Arcade::Init.db.transmit{ " update #{the_document.rid} set d.testkey2 = { 'nested_key2': 'nested_value2'} " }}
  ##  update set d += { key: { nested_key : nested_value } }
  Given{  Arcade::Init.db.transmit{ " update #{the_document.rid} set d += {'testkey3': { 'nested_key3': 'nested_value3'} }" } }
  ##  update set d += [ key: { nested_key : nested_value } ]
  Given{  Arcade::Init.db.transmit{ " update #{the_document.rid} set d += ['testkey4', { 'nested_key4': 'nested_value4' }]" }}
  Then { the_document.refresh.d == { testkey: { nested_key: 'nested_value' },
                                    testkey2: { nested_key2: 'nested_value2' },
                                    testkey3: { nested_key3: 'nested_value3' },
                                    testkey4: { nested_key4: 'nested_value4' }  }}
 end

 context "Using build-in update_map method"  do
  Given!( :the_document ){  TestDocument.insert name:"Bilding", age: rand(99) }
  Then { the_document.is_a? Arcade::TestDocument }
  Then { the_document.name == 'Bilding' }
  Then { the_document.d == nil  }

  Given!( :map_dataset ){ the_document.update_map :d, :testkey, { test_value:  77 }  }
  Given{ map_dataset.update_map :d, "testkey2", { test_value:  99 }  }
  Then { map_dataset.is_a? Arcade::TestDocument }
  Then { map_dataset.refresh.d == { testkey: { :test_value => 77 } , testkey2: { :test_value => 99 }  }}

 end
end
