require 'spec_helper'
require 'database_helper'
#require 'model_helper'
require 'rspec/given'

include Arcade

#/* -------------------------------------------------------------------------------------------------- */
#/*    Use Date, DateTime and Time in Properties                                                       */
#/*                                                                                                    */
#/*    Embedd a document in a database-class (document or vertex)                                      */
#/* -------------------------------------------------------------------------------------------------- */


RSpec.describe Arcade::Query do
  before( :all ) do
    clear_arcade
    DB= Arcade::Database.new :test
    Arcade::DatDocument.create_type
    Arcade::TestDocument.create_type
    TestDocument.insert date: Date.new( 2019,5,16 ), name:"hugi", age: rand(99)
    DatDocument.create date: Date.today, name: 'Hugi', age: rand(99)
      #Arcade::Init.db.execute { " insert into test_document set (name, age, emb) content 
      #                           { 'name': 'Äugi',''age': #{rand(99) }, 
      #                              { '@type': 'dat_document', 'name': 'ope', 'date': '#{Date.today.to_or}' }}" }
      d = DatDocument.new date: Date.new( 2022,4,5 ), name: 'berta', age: 25, rid: '#0:0'
      TestDocument.create date: Date.new( 1989, 4,2 ),name: "Tussi", age: rand(45),  emb: d,  many: [d]
  end # beforDatDocument.create Date: Date.today, name: 'Hugi', age: rand(99) e


  context "single documents" do
    Given( :the_document ){  TestDocument.find name: 'hugi'}
    Then { the_document.is_a? Arcade::TestDocument }
    Then { the_document.name == 'hugi' }

    Given( :date_document ){  DatDocument.where( name: 'Hugi').first }
    Then { date_document.is_a? Arcade::DatDocument }
    Then { date_document.name == 'Hugi' }
    Then { date_document.date == Date.today }
    Then { date_document.date.is_a? Date }
#
  end

  context "embedded documents"   do
    Given( :emb_document ){  TestDocument.find name:'Tussi'}
    Then { emb_document.is_a? Arcade::TestDocument }
    Then { emb_document.emb.is_a? Arcade::DatDocument }

  end
  context "many embedded documents"   do
    before(:all) do
      document = TestDocument.find name:'Tussi'
      list = ->{ DatDocument.new date: Date.new( 2022,rand(11)+1, rand(16)+1), name: 'Herta', age: rand(99), rid: '#0:0' }
#     list = ->{ DatDocument.new date: Date.new( 2022,11, 16), name: 'Herta', age: rand(99), rid: '#0:0' }

       Arcade::Init.db.execute{ " update #{document.rid} set  many += #{list[].to_json}" } 
       Arcade::Init.db.execute{ " update #{document.rid} set  many += #{list[].to_json}" } 

    end
    Given( :document ) { TestDocument.find name:'Tussi' }
    Then { document.refresh.many.is_a? Array }
    ## Get a specific row
   # Given( :result ) { Arcade::Init.db.query(" select many[ 1 ] from #{document.rid}").allocate_model }
    Given( :result) { document.query(projection: 'many[ 1 ]').execute.allocate_model }
    Then { result.is_a?  Array }
    Then { result.first.is_a? Arcade::DatDocument }
    Given( :query1 ) { document.query(projection: 'many[0..2]').execute.allocate_model }
    Then { query1.is_a?  Array }
    Then { query1.count == 2  }
    Then { query1.each{ |s|  expect(s).to be_a  Arcade::DatDocument }  }
    Given( :query2 ) { document.query(projection: 'many[1..3]').execute.allocate_model }
    Then { query2.is_a?  Array }
    Then { query2.count == 2  }
    Given( :query3 ) { document.query(projection: 'many.size()').execute.select_result.first }
    Then { query3.is_a?  Integer }
    Then { query3 == 3  }
    Given( :query4 ) { document.query(projection: 'many.name').execute.select_result }
    Then { query4.is_a?  Array }
    Then { query4.count == 3  }
    Then { query4 == ['berta','Herta', "Herta"]  }
    Given( :query5 ) { document.query(projection: 'many:{name} as test').execute.first[:test] }
    #  test: [ { name: 'berta' }, { name: 'Herta' }  usw...
    Then { query5.is_a?   Array }
    Then { query5.count == 3   }
    Then { query5 ==  [{:name=>"berta"}, {:name=>"Herta"}, {:name=>"Herta"}] }
  end
end
