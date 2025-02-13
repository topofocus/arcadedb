require 'spec_helper'
require 'database_helper'
require 'rspec/given'
###
# The model directory  `spec/model` contains some sample files
# #
# These are used in the following tests
#
# In projects, define the model files and include them  via zeitwerk
#
#    loader = Zeitwerk::Loader.new
#    loader.push_dir("#{__dir__}/model")
#    loader.setup
#
#
RSpec.describe Arcade::Document do
  before(:all) do
    connect
    db = Arcade::Init.db
#    db.begin_transaction
    Arcade::TestDocument.create_type
    Arcade::TestDocument.delete all: true
  end
  after(:all) do
     db = Arcade::Init.db
 #    db.rollback
  end


  context "in situ creation of a TestDocument" do
    #  in_situ = DB.query " select from test_document order by @rid limit 1"
    #
    Given( :in_situ ){  [{ :@type=>"test_document",  :date=> Date.parse("2019-05-26"), :name=>"imwera", :age=>16}] }
   When( :model ){ in_situ.allocate_model }
   Then { model.is_a? Array }
   When( :document ){ model.first }
   Then { document.is_a? Arcade::TestDocument }
   Then { document.rid == "#0:0" }
   Then { document.name == "imwera" }
   Then { document.age == 16 }
   Then { document.date ==  Date.new( 2019,5,26 ) }

  end
  context "Real field studies" do
    before(:all) do
      hugo = Arcade::TestDocument.insert name: "Hugo"
      Arcade::TestDocument.insert name: 'Berta', married_to: hugo,
                                                 d: { a: 2, b: 45, c: 67 }
      a= Arcade::DatDocument.new( date: Date.today ,   rid: "#0:0")
      b= Arcade::DatDocument.new( date: Date.today-1 , rid: "#0:0")
      c= Arcade::DatDocument.new( date: Date.today-2 , rid: "#0:0")

      Arcade::TestDocument.insert name: 'Karl',  dat: [a,b,c]
    end
  context "Document with a link property" do


    Given( :document ){ Arcade::TestDocument.find name: 'Berta' }
    Given( :linked_document ){ Arcade::TestDocument.find name: 'Hugo' }  # the linked document is
                                                                         # loaded seperately. There is
                                                                         # no caching!
                                                                         # ToDo: Implement lazy loading
    Then { document.married_to == linked_document.rid }
    Then { document.d == { a: 2, b: 45, c: 67 } }
  end
  context "Document with an embedded Hash" do

    Given( :emb_document ){ Arcade::TestDocument.find name: 'Karl' }
    Then { emb_document.dat.each{|y| y.is_a? Arcade::DatDocument}  }

  end

  end
end
