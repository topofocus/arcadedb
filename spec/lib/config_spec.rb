require 'spec_helper'
RSpec.describe Arcade::Config do
  context "dry configurable" do
    subject{ Arcade::Config }
    [:database, :username, :password, :base_uri, :logger, :namespace].each do  | element |
      its(:methods) { is_expected.to include element }
    end
  end
  context "Top level keys" do
    subject { Arcade::Config.yml }
    it { expect( subject).to be_a Hash }
    it { expect( subject.keys ).to eq [:pg, :environment, :admin, :logger, :namespace] }
  end
end
