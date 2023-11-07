

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
#/*    Date is only stored as Date-Field in the database if a `date`-property is used                  */
#/*    If an ad-hoc database is used, dates are stored as strings                                      */
#/* -------------------------------------------------------------------------------------------------- */


RSpec.describe Arcade::Query do
  before( :all ) do
    connect
    db = Arcade::Init.db
    db.begin_transaction
    Arcade::DatDocument.create_type
#CREATE PROPERTY dat_document.date DATE
#CREATE PROPERTY dat_document.name STRING
#CREATE PROPERTY dat_document.age INTEGER
#CREATE INDEX  ON dat_document (date) UNIQUE

    Arcade::TestDocument.create_type
#CREATE PROPERTY test_document.name STRING
#CREATE PROPERTY test_document.age INTEGER
#CREATE PROPERTY test_document.d  MAP
#CREATE PROPERTY test_document.emb  EMBEDDED
#CREATE PROPERTY test_document.many  LIST
#CREATE INDEX  ON test_document (name, age) UNIQUE

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


end
