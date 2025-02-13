require 'spec_helper'
require 'database_helper'
require 'rspec/given'
###
# The model directory  `spec/model` contains some sample files
# #
# These are used in the following tests
#
RSpec.describe Arcade::Document do
  before(:all) do
    db = Arcade::Init.db
    Arcade::TestDocument.create_type
    My::EmbeddedDocument.create_type
    My::Alist.create_type
    My::Aset.create_type
#    db.begin_transaction
    Arcade::DatDocument.delete all: true
    My::EmbeddedDocument.delete all: true
    My::Alist.delete all: true
    My::Aset.delete all: true

  end
  after(:all) do
     db = Arcade::Init.db
 #    db.rollback
  end

  context "work on the generated schema of base"  do
    before(:all) do
      My::EmbeddedDocument.insert a_set: { home: 'test' }, label: 'Test1'
      My::EmbeddedDocument.insert a_set: { home: 'test2', currency: { 'EUR' => 4.32} }, label: 'Test2'
    end

    Given( :embedded ){  My::EmbeddedDocument.where(label: 'Test1').first }
    Then { embedded.a_set.is_a? Hash }
    Then { embedded.a_set == { home: 'test'} }
    Then { embedded.a_set[:home] == 'test' }

    Given( :embedded2 ){  My::EmbeddedDocument.where(label: 'Test2').first }
    Then { embedded2.a_set[:currency][:EUR]  == 4.32 }
  end

    #---------------------------  document list  ---------------------------------------------------- #

    context "realize a 1:n  relation on real documents"  do
      before( :all  ) do
        My::Alist.insert name: 'testrecord 1', number: 1
        My::Alist.insert name: 'testrecord 2', number: 2
        My::EmbeddedDocument.insert emb:  My::Alist.all, label: "Test3"
      end

    Given( :embedded3 ){  My::EmbeddedDocument.where(label: 'Test3').first }
      Then{ embedded3.is_a? My::EmbeddedDocument }
      Then{ embedded3.emb.is_a? Array }
      Then{ embedded3.emb.each{ |y| y.is_a? My::Alist  }}
      Then{ embedded3.emb.first.number == 1  }
      Then{ embedded3.emb.last.number == 2  }


  #      emb.emb.each{|y| expect( y ).to be_a My::Alist }
  #      emb.emb.each{|y| expect( y ).to be_a My::Alist }

      it "select connected properties" do
        ##  returns just the numbers
        expect( My::EmbeddedDocument.query( projection: 'emb.number' ).query
                                                                      .select_result.compact)
                                                         .to eq [1,2]
        ## returns an Array of Hashes
        expect( My::EmbeddedDocument.query( projection: 'emb:{number}' ).execute
                                                                        .select_result.compact)
                                                        .to eq [{number: 1},{ number: 2}]
        ## returns the linked dataset(s)
        expect( My::EmbeddedDocument.query( projection: 'emb[number=1]' ).execute
                                                                         .select_result.compact)
                                                         .to eq  [ My::Alist.where(number: 1).first]
      end

    end

    #--------------------------- embedded list  ---------------------------------------------------- #

    context "realize a 1:n  relation on embedded documents"  do
      before( :all  ) do
        a = My::Alist.new name: 'testrecord 1', number: 1, rid: "#0:0"
        b = My::Alist.new name: 'testrecord 2', number: 2, rid: "#0:0"
        c= My::EmbeddedDocument.insert emb:  My::Alist.all, label: "Test3"
        c.update_list :emb, a
        c= c.refresh  # necessary because update_list still works on c without or with empty property `emb`
        c.update_list :emb, b
      end

    ##  simply a where statement loads embe3dded datasets as hash
    Given( :embedded3 ){  My::EmbeddedDocument.where(label: 'Test3').first }
      Then{ puts embedded3.inspect }
      Then{ embedded3.is_a? My::EmbeddedDocument }
      Then{ embedded3.emb.is_a? Array }
      Then{ embedded3.emb.each{ |y| y.is_a? My::Alist  }}
      Then{ embedded3.emb.first.is_a? Hash  }
      Then{ embedded3.emb.first[:number] == 1  }
      Then{ embedded3.emb.last[:number] == 2  }

    ##  After expanding, the embedded document is accessible
    When( :query) { embedded3.query expand: :emb  }
      Then{ query.to_s == "select  expand ( emb ) from "+ embedded3.rid + " " }
      Then{ query.execute ==   [{:number=>1, :@type=>"my_alist", :name=>"testrecord 1"},
                                {:number=>2, :@type=>"my_alist", :name=>"testrecord 2"}] }


      Then{ query.execute.allocate_model.each{ |x| x.is_a My::Alist } }

    Given( :expanded_query ){ My::EmbeddedDocument.query( expand: :emb )
                                                  .execute
                                                  .allocate_model }
      Then { expanded_query.is_a?  Array }
      Then { expanded_query.size == 2 }
      Then { expanded_query.map{|x| x.number} == [1,2] }


    Given( :projected_query ){ My::EmbeddedDocument.query( projection: 'emb.number' )
                                                    .execute
                                                    .select_result
                                                    .compact }
     Then{ projected_query == [1,2] }
        ## returns an Array of Hashes
    Given( :alternative_projection ){ My::EmbeddedDocument.query( projection: 'emb:{number}' )
                                                             .execute
                                                             .select_result
                                                             .compact }
      Then { alternative_projection == [{number: 1},{ number: 2}] }

      # ................................ update of emedded douments ................ #
      #  the update of list.entries is not implemented in the database
      #  this is a recepie for a walk araound
      #
      context "update per algo" do
        before(:all) do
         embedded_documents =  My::EmbeddedDocument.query( expand: :emb, where: { label: 'Test3' } )
                                                  .execute
                                                  .allocate_model
         My::EmbeddedDocument.update set: {emb:   [] } , where: { label: 'Test3' }
         doc =  My::EmbeddedDocument.find label: 'Test3'
         embedded_documents.each do | emb |
           #  algo --> add 1!
           doc = doc.refresh if doc.emb == []
           doc.update_list :emb, My::Alist.new(  emb
                                                 .invariant_attributes
                                                 .merge( rid: '#0:0', number: emb.number + 1 ))
         end
        end

      Then { projected_query == [2,3] }
        end
    end





    context " embeded  Hash in property `a_set`"  do
      before(:all) do

        the_structure = [{ :key=>"WarrantValue", :value=> 8789, :currency=>"HKD"},
                         { :key=>"WhatIfPMEnabled", :value=> true, :currency=>""},
                         { :key=>"TBillValue", :value=> 0, :currency=>"HKD"     } ]

        the_hash =	Hash[  the_structure.map{|x| [x[:key].underscore.to_sym, [x[:value], x[:currency] ] ] } ]
        My::EmbeddedDocument.insert( a_set: the_hash, label: "Test4")
      end

      Given( :a_set ){  My::EmbeddedDocument.where(label: 'Test4').first.a_set }
      Then { a_set.is_a? Hash }
      Then { a_set.size == 3 }
      Then { a_set.keys.include? :what_if_pm_enabled }
      Then { a_set[:what_if_pm_enabled] == [ true, ""] }
      Then { a_set[:warrant_value] == [ 8789, 'HKD'] }

      context "update a selected element" do 
        before(:all) do
          item =  My::EmbeddedDocument.where(label: 'Test4').first
          item.update_map :a_set,  :what_if_pm_enabled, ["false, """]
        end
      Given( :a_set ){  My::EmbeddedDocument.where(label: 'Test4').first.a_set }
      Then { a_set[:what_if_pm_enabled] == [ false, ""] }

      end
  end


    #--------------------------- embedded records  (Hash)  ------------------------------------ #
    context " embeded  records in property `a_set`"  do
      before(:all) do

        the_structure = [{ :key=>"WarrantValue", :value=> 8789, :currency=>"HKD"},
                         { :key=>"WhatIfPMEnabled", :value=> true, :currency=>""},
                         { :key=>"TBillValue", :value=> 0, :currency=>"HKD"     } ]

        the_hash =	Hash[  the_structure.map{|x| [x[:key].underscore.to_sym, [x[:value], x[:currency] ] ] } ]
        My::EmbeddedDocument.insert( a_set: the_hash, label: "Test4")
      end

      Given( :a_set ){  My::EmbeddedDocument.where(label: 'Test4').first.a_set }
      Then { a_set.is_a? Hash }
      Then { a_set.size == 3 }
      Then { a_set.keys.include? :what_if_pm_enabled }
      Then { a_set[:what_if_pm_enabled] == [ true, ""] }
      Then { a_set[:warrant_value] == [ 8789, 'HKD'] }
  end
end
#  working: 
#  select from base where  a_set containskey '"currency' 
#  select from base where  a_set.currency containskey 'EUR'
#  not working
#  select from base where a_set.currency = "EUR"
#  select from base where "EUR" in a_set.currency
#
