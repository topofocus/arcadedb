require 'spec_helper'
require 'database_helper'
require 'rspec/given'
###
# ArcadeDB types can be declared as immutable
# Then only queries and insert-operations are possible
#
RSpec.describe Arcade::Base do
  before(:all) do
    connect
    db = Arcade::Init.db
    My::V1.create_type
    My::E1.create_type
#    db.begin_transaction
    My::V1.delete all: true
    g,a,b,c = ["Gateway", "ServiceA", "ServiceB", "ServiceC"].map {|y| My::V1.insert a: y}
    request='get_user_info'
    g.assign via: My::E1, to: a, request: request
    g.assign via: My::E1, to: b, request: "delete_user"
    a.assign via: My::E1, to: c, request: request
    c.assign via: My::E1, to: b, request: request

  end
  after(:all) do
     db = Arcade::Init.db
 #    db.rollback
  end



  context "check setup" do

    Given( :gateway  ){ My::V1.find a: 'Gateway' }
    Then { gateway.out.size == 2 }
    When ( :deleted_service ){ My::V1.where a: 'ServiceB' }
    When ( :request_service ){ My::V1.where a: 'ServiceA' }
    Then { gateway.nodes( :outE, where: { request: "delete_user" }) == deleted_service }
    Then { gateway.nodes( :outE, where: { request: "get_user_info" }) == request_service }

  end

  context "get deleted User relation" do
    Given( :gateway_record ){ Arcade::Match.new type: My::V1, where:{ a: 'Gateway' }, as: :g }
    Given( :gateway  ){ My::V1.where a: 'Gateway' }
    Given ( :deleted_service ){ My::V1.where a: 'ServiceB' }
    Then  { gateway_record.to_s == "MATCH { type: my_v1, where: ( a='Gateway' ), as: g } RETURN g " }
    Then  { gateway_record.execute.select_result ==  gateway}

    Given( :deleted_user_record  ){ gateway_record.outE( My::E1,  where: { request: 'delete_user' }).node(as: :f) }
    Then { deleted_user_record.to_s == "MATCH { type: my_v1, where: ( a='Gateway' ), as: g }.outE('my_e1'){ where: ( request='delete_user' ) }.inV(){ as: f } RETURN g,f " }
    Then { deleted_user_record.execute.allocate_model  ==   gateway + deleted_service }
  end

end
