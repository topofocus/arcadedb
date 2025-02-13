require 'spec_helper'
require 'database_helper'
#require 'model_helper'
require 'rspec/given'

include Arcade

#/* -------------------------------------------------------------------------------------------------- */
#/*    Embedd a document in a database-class (document or vertex)                                      */
#/* -------------------------------------------------------------------------------------------------- */


RSpec.describe Arcade::Query do
  before( :all ) do
    connect
    db = Arcade::Init.db
    Arcade::DatDocument.create_type
    Arcade::TestDocument.create_type
#    db.begin_transaction
    Arcade::DatDocument.delete all: true
    Arcade::TestDocument.delete all: true
      Arcade::TestDocument.insert date: Date.new( 2019,5,16 ), name:"hugi", age: rand(99)
      Arcade::TestDocument.insert date: Date.new( 2020,5,16 ), name:"imara", age: rand(99)
    Arcade::DatDocument.insert date: Date.today, name: 'Hugi', age: rand(99)
      #Arcade::Init.db.execute { " insert into test_document set (name, age, emb) content 
      #                           { 'name': 'Äugi',''age': #{rand(99) }, 
      #                              { '@type': 'dat_document', 'name': 'ope', 'date': '#{Date.today.to_or}' }}" }
      d = Arcade::DatDocument.new date: Date.new( 2022,4,5 ), name: 'berta', age: 25, rid: '#0:0'
      Arcade::TestDocument.insert date: Date.new( 1989, 4,2 ),name: "Tussi", age: rand(45),  emb: d
      Arcade::TestDocument.insert date: Date.new( 1989, 4,3 ),name: "karl", age: rand(45),  many: [d]
  end # beforDatDocument.insert Date: Date.today, name: 'Hugi', age: rand(99) e

  after(:all) do
     db = Arcade::Init.db
 #    db.rollback
  end

  context "single documents"  do
    Given( :the_document ){  Arcade::TestDocument.find name: 'hugi'}
#    it{  puts Arcade::TestDocument.all.map &:to_human }
#    it{  puts Arcade::DatDocument.all.map &:to_human }
    Then { the_document.is_a? Arcade::TestDocument }
    Then { the_document.name == 'hugi' }

    Given( :date_document ){  Arcade::DatDocument.where( name: 'Hugi').first }
    Then { date_document.is_a? Arcade::DatDocument }
    Then { date_document.name == 'Hugi' }
    Then { date_document.date == Date.today }
    Then { date_document.date.is_a? Date }
#
  end

  context "embedded document created upon creating the main type"   do
    Given( :emb_document ){  Arcade::TestDocument.find name:'Tussi'}
    Then { emb_document.is_a? Arcade::TestDocument }
    Then { emb_document.emb.is_a? Arcade::DatDocument }
    Then { emb_document.emb.name == 'berta' }
  end


  ### ---------- a single embedded document -----------
  ###            similar to a link

  context "add an embedded document"  do
    before( :all ) do
    the_document = Arcade::TestDocument.find name: 'imara'
    the_document.insert_document :emb,
                                 DatDocument.new(date: Date.new( 2022,4,5 ),
                                                 name: 'berta',
                                                 age: 25 ,
                                                 rid: '#0:0')
    end

    Given( :the_document ){  Arcade::TestDocument.find name: 'imara'}
    Then { the_document.emb.is_a? Arcade::DatDocument }
    Then { the_document.emb.name == 'berta' }
  end


  context "update an embedded document" do
    before(:all) do
    emb_document =  Arcade::TestDocument.find name:'Tussi'

    emb_document.update_embedded :emb, :name, 'Gertrude'
    end
    Given( :emb_document ) { Arcade::TestDocument.find name:'Tussi'}
    Then { emb_document.emb.is_a? Arcade::DatDocument }
    Then { emb_document.refresh.emb.name == 'Gertrude' }
  end

  ### ---------- a list of  embedded documents -----------
  ###            similar to a 1:n relation

  context "many embedded documents" , focus: true   do
    before(:all) do
      document = Arcade::TestDocument.find name:'karl'
      list = ->(a){ Arcade::DatDocument.new date: Date.new( 2022,rand(11)+1, rand(16)+1), name: 'Herta'+a, age: rand(99), rid: '#0:0' }

       Arcade::Init.db.transmit{ " update #{document.rid} set  many += #{list["w"].to_json}" } 
       Arcade::Init.db.transmit{ " update #{document.rid} set  many += #{list["x"].to_json}" } 

    end
    Given( :document ) { Arcade::TestDocument.find name:'karl' }
    it{  puts document.to_human }
#    it{  puts Arcade::TestDocument.all.map &:to_human }

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
    Then { query4 == ['berta','Hertaw', "Hertax"]  }
    Given( :query5 ) { document.query(projection: 'many:{name} as test').execute.first[:test] }
    #  test: [ { name: 'berta' }, { name: 'Herta' }  usw...
    Then { query5.is_a?   Array }
    Then { query5.count == 3   }
    Then { query5 ==  [{:name=>"berta"}, {:name=>"Hertaw"}, {:name=>"Hertax"}] }
    ## query the 1:n relation
    ## for now, the returned records  are not recognized as model-data. therfore "rid: #0:0" has to be merged manually
    Given( :query6a ) { TestDocument.query expand: :many , where: "many contains( name='berta' )" }
    Given( :query6 ) { Query.new( from: query6a,  where: { name: 'berta'}) }
    Then { query6.to_s == "select from  ( select  expand ( many ) from test_document where many contains( name='berta' )  )  where name='berta' " }
    When( :selected ) { query6.execute  }
    Then { selected.is_a? Array   }
    And  { selected.first.is_a? Hash }
    Then { selected.first.merge( {:"@rid" => "#0:0"} ).allocate_model.is_a? Arcade::DatDocument }




  end
end
