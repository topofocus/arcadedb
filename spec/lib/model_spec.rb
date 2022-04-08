require 'spec_helper'

RSpec.describe Arcade do
  context "Has a proper version" do
	  it{ expect( Arcade::VERSION ).to be_a Numeric } 
  end
end
