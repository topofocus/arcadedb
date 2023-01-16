
## This is an init-script intended to be copied to
## rails-root/config/initializers

module Arcade
  ProjectRoot =  Rails.root 
  puts "Root: #{Rails.root}"
  puts "Alternative: #{File.expand_path("../",__FILE__)}"
end
## Integrate a namespaced model
#module HC
#
#end







