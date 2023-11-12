# REQUIREMENTS
# Install iruby and include the gem in the Gemfile
# 
# For visualisations
# include vega in the Gemfile
#
# require this file at the top of each notebook

require 'bundler/setup'
require 'arcade'
require 'dry/struct'
require 'iruby'
require 'vega'
module Types
  include Dry.Types()
end
class Array

  def method_missing(method, *key)
    unless method == :to_hash || method == :to_str #|| method == :to_int
      return self.map{|x| x.public_send(method, *key)}
    end
  end

  #def to_html
  #  map{|y| IRuby.display IRuby.table y.html_attributes } 
  #end
    

  def to_html
    if first.respond_to? :html_attributes
      title =  first.html_attributes.keys
      body = map{|y| y.html_attributes.values }
      #  map{|y| IRuby.display IRuby.table html_attributes }  # alternative approach
      IRuby.display IRuby.table [ title ] + body

    else
      each{|y| IRuby.display IRuby.html y }
    end
  end
                    
                    

  def inspect
  end
    
end # Array

module Arcade
  class Base
    def inspect
    end
  end
end

  include  Arcade
  require 'irb'

begin
environment ||=  :development
IRuby.display IRuby.html "<h2>Arcade Stock Database </h2>"
IRuby.display IRuby.html "<h3>#{environment.to_s.capitalize} Environment </h3>"
Arcade::Init.connect environment
DB =  Stock::Init.db
#require 'pry'
require 'irb'
ARGV.clear

rescue  Dry::Struct::Error, Dry::Types::MissingKeyError => e
  ARGV.clear
  puts "Maintance Modus: Please repair the Database"
  puts e.inspect
end
