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
## unfortunately, this does not work
#loader =  Zeitwerk::Loader.new
#loader.push_dir ("#{__dir__}/model")
#loader.setup
#- ..therefore the manual walkaround:
require 'model_helper'

read_yml = -> (key) do
	YAML::load_file( File.expand_path('../spec.yml',__FILE__))[key]
end
Arcade::Init.connect :test

RSpec.configure do |config|
	config.mock_with :rspec
	config.color = true
	# enable running single tests
	config.filter_run :focus => true
	config.run_all_when_everything_filtered = true
  ## because we are testing database-sequences:
	config.order = 'defined'  # "random"
end

## enable testing of private methods
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
