require 'bundler/setup'
require 'yaml'
require 'rspec'
require 'rspec/its'
require 'rspec/collection_matchers'
require 'yaml'
require 'zeitwerk'
#require 'active_support'

require 'arcade'
require 'postgres_helper'
module My; end
puts "---"
puts "#{__dir__}/model"
puts "---"

#loader =  Zeitwerk::Loader.new
#loader.push_dir ("#{__dir__}/model")
#loader.setup
#require_relative "../spec/model/test_vertex"
#require_relative "../spec/model/test_edge"
#require_relative "../spec/model/test_document"
#require_relative "../spec/model/test_query"
#require_relative '../spec/model/my/names'
#require_relative '../spec/model/my/surnames'
#require_relative '../spec/model/my/v1'
#require_relative '../spec/model/my/v2'
#require_relative '../spec/model/my/v3'
#require_relative '../spec/model/my/e1'
#require_relative '../spec/model/my/e2'
#require_relative '../spec/model/my/e3'
#require_relative '../spec/model/my/e4'
#require_relative '../spec/model/connects'
#require_relative '../spec/model/base'
#require_relative '../spec/model/node'
#require_relative '../spec/model/extra_node'
require 'model_helper'
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
