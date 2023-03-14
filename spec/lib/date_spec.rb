require 'spec_helper'
require 'database_helper'
#require 'model_helper'
require 'rspec/given'

include Arcade

RSpec.describe Arcade::Query do
  before( :all ) do
    clear_arcade
    DB= Arcade::Database.new :test
    Arcade::DatDocument.create_type
    Arcade::TestDocument.create_type
    TestDocument.insert name:"hugi", age: rand(99)
    DatDocument.create Date: Date.today, name: 'Hugi', age: rand(99)
      #Arcade::Init.db.execute { " insert into test_document set (name, age, emb) content 
      #                           { 'name': 'Äugi',''age': #{rand(99) }, 
      #                              { '@type': 'dat_document', 'name': 'ope', 'date': '#{Date.today.to_or}' }}" }
      d = DatDocument.new date: Date.new( 2022,4,5 ), name: 'berta', age: 25, rid: '#0:0'
      TestDocument.create name: "Tussi", emb: d
  end # beforDatDocument.create Date: Date.today, name: 'Hugi', age: rand(99) e


  context "single documents" do
    Given( :the_document ){  TestDocument.first}
    Then { the_document.is_a? Arcade::TestDocument }
    Then { the_document.name == 'hugi' }

    Given( :date_document ){  DatDocument.first }
    Then { date_document.is_a? Arcade::DatDocument }
    Then { date_document.name == 'hugi' }
    Then { date_document.date == Date.today }
    Then { date_document.date.is_a? Date }
#
  end

  context "embedded documents" , focus: true  do 
    before(:all) do
    end
    Given( :emb_document ){  TestDocument.find name:'Äugi'}
    Then { emb_document.is_a Arcade::TestDocument }

  end
end
