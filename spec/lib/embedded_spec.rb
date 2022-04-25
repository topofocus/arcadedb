require 'spec_helper'
require 'spec_helper'
require 'database_helper'
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
    clear_arcade
    DB = Arcade::Database.new :test
    Arcade::TestDocument.create_type
    My::EmbeddedDocument.create_type
    My::Alist.create_type
    My::Aset.create_type
  end

  context "work on the generated schema of base"  do
    it "insert an embedded map" do
      My::EmbeddedDocument.create a_set: { home: 'test' }, label: 'Test1'
      expect( My::EmbeddedDocument.count ).to eq 1
      expect( My::EmbeddedDocument.first.a_set).to be_a Hash
      expect( My::EmbeddedDocument.where(label: 'Test1').first.a_set ).to eq  home: 'test'
      expect( My::EmbeddedDocument.where(label: 'Test1').first.a_set[:home] ).to eq   'test'
      My::EmbeddedDocument.create a_set: { home: 'test4', currency: { 'EUR' => 4.32} }, label: 'Test4'
      expect(My::EmbeddedDocument.last.a_set[:currency][:EUR]).to eq 4.32
    end

    context "query for an embedded map" do

      ### query for :currency => {"EUR" => something }
      subject{ My::EmbeddedDocument.query.where(  "a_set.currency containskey 'EUR'" ).execute.allocate_model }
      it { is_expected.to  be_a Array }
      it { is_expected.to have(1).item }
      it { expect(subject.first.a_set[:currency][:EUR]).to eq 4.32 }
    end


    context "insert a 1:1 relation"  do
      before( :all  ) do
        My::Alist.create name: 'testrecord 1', number: 1
        My::Alist.create name: 'testrecord 2', number: 2
      end

      it "check the embedded properties" do
        emb = My::EmbeddedDocument.create emb:  My::Alist.all
        expect( emb.emb ).to be_an Array
  #      emb.emb.each{|y| expect( y ).to be_a My::Alist }
  #      emb.emb.each{|y| expect( y ).to be_a My::Alist }
      end

      it "select embedded properties" do
        ##  returns just the numbers
        expect( My::EmbeddedDocument.query( projection: 'emb.number' ).query.select_result("emb.number")).to eq [[[1,2]]]
        ## returns an Array of Hashes
        expect( My::EmbeddedDocument.query( projection: 'emb:{number}' ).execute.select_result( "emb")).to eq [[[{number: 1},{ number: 2}]]]
        ## returns the linked dataset(s)
        expect( My::EmbeddedDocument.query( projection: 'emb[number=1]' ).execute.select_result("emb[number = 1]")).to eq  [[[ My::Alist.where(number: 1).first.rid]]]

      end
    end

    context " embedd  records,"  do
      before(:all) do

        the_structure = [{ :key=>"WarrantValue", :value=>"8789", :currency=>"HKD"},
                         {	:key=>"WhatIfPMEnabled", :value=>"true", :currency=>""},
                         { :key=>"TBillValue", :value=>"0", :currency=>"HKD" } ]

        the_hash =	Hash[  the_structure.map{|x| [x[:key].underscore.to_sym, [x[:value], x[:currency] ] ] } ] 
        @b =  My::EmbeddedDocument.create( a_set: the_hash) 
      end
      context "the default embedded set" do
        subject { @b.a_set }
        it{ is_expected.to be_a Hash }
        its(:size){ is_expected.to eq 3 }
        its(:keys){ is_expected.to include :what_if_pm_enabled  }
        its(:values){ is_expected.to include ["8789","HKD"]  }
        it "can be accessed by key" do
          expect( subject[:warrant_value].first ).to eq "8789"
        end
      end
    end
  end
end
#  working: 
#  select from base where  a_set containskey '"currency' 
#  select from base where  a_set.currency containskey 'EUR'
#  not working
#  select from base where a_set.currency = "EUR"
#  select from base where "EUR" in a_set.currency
#
