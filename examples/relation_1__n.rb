##
## This example realises a 1:n relation  using  a `embedded`property
#
## Its implemented in modelfiles located in spec/model
#  and runs in the test environment.
##
require 'bundler/setup'
require 'zeitwerk'
require 'arcade'

include Arcade
## require modelfiles
loader =  Zeitwerk::Loader.new
loader.push_dir ("#{__dir__}/../spec/model")
loader.setup

## clear test database

databases =  Arcade::Api.databases
if  databases.include?(Arcade::Config.database[:test])
  Arcade::Api.drop_database Arcade::Config.database[:test]
end
Arcade::Api.create_database Arcade::Config.database[:test]

## Universal Database handle
DB = Arcade::Init.connect 'test'

## ------------------------------------------------------ End Setup ------------------------------------- ##
##
## We are realising  a self referencing  relation
##  name -->   children
#


Ex::NewNames.create_type                              # initialize the database
                                                      # spec/models/ex/new_names.rb
                                                      # Put same names into the database
table = %w( Guthorn Fulkerson Sniezek Tomasulo Portwine Keala Revelli Jacks Gorby Alcaoa ).map do | name |
  Ex::NewNames.insert name: name, age: rand(99)
end
                                                      # Connect randomly
children = (0..6).map{ | i | table[-i].rid    }
puts children
i = 0
table.each.with_index do  | n, i |
   n.update  children: [ children[i] &.rid, table[ rand(10)+5] &.rid].compact
end

puts "-------------------- raw data ---------------------------"
puts Ex::NewNames.all false

puts "--------------- Parent and Children ---------------------"

children_query  = Ex::NewNames.query projection:  ['name as parent', 'children[age]']
puts children_query.query

