# A sample Guardfile
# More info at https://github.com/guard/guard#readme
def fire
  require "ostruct"

  # Generic Ruby apps
  rspec = OpenStruct.new
  rspec.spec = ->(m) { "spec/#{m}_spec.rb" }
  rspec.spec_dir = "spec"
  rspec.spec_helper = "spec/spec_helper.rb"


  watch(%r{^spec/.+_spec\.rb$})
#  watch(%r{^spec/usecase/(.+)\.rb$})
  watch(%r{^arcade/(.+)\.rb$})     { |m| "spec/arcade/#{m[1]}_spec.rb" }
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
#  watch(%r{^examples/time_graph/spec/(.+)_spec\.rb$}) 
#  watch('examples/time_graph/spec/create_time_spec.rb') 
  watch('spec/spec_helper.rb')  { "spec" }

  watch(%r{^spec/arcade/(.+)_spec\.rb$})  
end


#interactor :simple
#if RUBY_PLATFORM == 'java' 
#guard( 'jruby-rspec') {fire}  #', :spec_paths => ["spec"]
#else
guard( :rspec, cmd: "bundle exec rspec --format documentation ") { fire }
#end
