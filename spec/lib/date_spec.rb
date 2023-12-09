

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
#/*                                                                                                    */
#/*    Dates are only retreived as Date-Objects if DryStruct::JSON::Date or DryStruct::Params::Date    */
#/*    Validations are used. Even then, sometimes Unitx-timestamps are received. Therefor its          */
#/*    necessary to use the custom DryStruct::Date Modification as introduced in My::V3                */
#/* -------------------------------------------------------------------------------------------------- */


RSpec.describe Arcade::Query do
  before( :all ) do
    connect
    db = Arcade::Init.db
    Arcade::DatDocument.create_type
    My::V3.create_type
    My::E1.create_type

    Arcade::TestDocument.create_type

    db.begin_transaction
    Arcade::TestDocument.delete all: true
    Arcade::DatDocument.delete all: true
    My::V3.delete all:true
## insert a record with an ad-hoc date field
    TestDocument.insert date: Date.new( 2019,5,16 ), name:"hugi", age: rand(99)
## insert a  record with a predefined date property
    DatDocument.insert date: Date.today, name: 'Hugi', age: rand(99)
# create a headless document without a rid
    d = DatDocument.new date: Date.new( 2022,4,5 ), name: 'berta', age: 25, rid: '#0:0'
#  insert into list and embedded
    TestDocument.insert date: Date.new( 1989, 4,2 ),name: "Tussi", age: rand(45),  emb: d,  many: [d]
  end # before
  after(:all) do
     db = Arcade::Init.db
     db.rollback
  end

  context "single documents"  do
    Given( :the_document ){  TestDocument.find name: 'hugi'}
    Then { the_document.is_a? Arcade::TestDocument }
    Then { the_document.name == 'hugi' }
    Then { the_document.date.is_a? String }

    Given( :date_document ){  DatDocument.where( name: 'Hugi').first }
    Then { date_document.is_a? Arcade::DatDocument }
    Then { date_document.name == 'Hugi' }
    Then { date_document.date == Date.today }
    Then { date_document.date.is_a? Date }
#
  end

  ## Tests passing with
  ##   Types::Params::Date
  ## and
  ##   Types::JSON::Date
  ##
  ## but fail with
  ##   Types::Date                --> converts Date to a Date-String
  ## and
  ##   Types::Nominal::Date       --> converts Date to a Date-String
  ##
  ## ---> USE the Types::Date-Modification in My::V3a           <---

  context "Node-Edge-Node Environment" do
    before( :all  ) do 
#      My::V3.delete all: true
      v= My::V3.insert datum: Date.new(2014,5,6), a: "eins"
      v.assign via: My::E1, vertex: My::V3.insert( datum: Date.new(2024,5,6), a: 'zwei' )
    end

    Given( :the_primary_vertex ){ My::V3.where( a: 'eins' ).first }
    Then {  the_primary_vertex.datum.is_a? Date }
    it { puts the_primary_vertex.attributes }
    Then {  the_primary_vertex.datum == Date.new( 2014,5,6 ) }
    When( :the_second_vertex ){ the_primary_vertex.nodes(:out, via: My::E1).first }
    it { puts Arcade::Init.db.query "select out('my_e1') from #{the_second_vertex.rid}" }
    Then{ the_second_vertex.datum == Date.new( 2024,5,6  ) }

    Then{ the_second_vertex.in.first.datum == Date.new(2014,5,6) }

  end

end
