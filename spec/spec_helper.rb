require 'bundler/setup'
require 'yaml'
require 'rspec'
require 'rspec/its'
require 'rspec/collection_matchers'
require 'yaml'
#require 'active_support'

require 'arcade'
require 'postgres_helper'
require_relative "../spec/model/test_vertex"
require_relative "../spec/model/test_edge"
require_relative "../spec/model/test_document"
require_relative "../spec/model/test_query"
require_relative '../spec/model/my/names'
read_yml = -> (key) do
	YAML::load_file( File.expand_path('../spec.yml',__FILE__))[key]
end
Arcade::Init.connect :test

RSpec.configure do |config|
	config.mock_with :rspec
	config.color = true
	# ermöglicht die Einschränkung der zu testenden Specs
	# durch  >>it "irgendwas", :focus => true do <<
	config.filter_run :focus => true
	config.run_all_when_everything_filtered = true
	config.order = 'defined'  # "random"
end

RSpec.shared_context 'private', private: true do

    before :all do
          described_class.class_eval do
	          @original_private_instance_methods = private_instance_methods
		        public *@original_private_instance_methods
			    end
	    end

      after :all do
	    described_class.class_eval do
	            private *@original_private_instance_methods
		        end
	      end

end
