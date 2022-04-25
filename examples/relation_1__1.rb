##
## This example realises a unidirectional Graph using
## the document database primitve #and a self referencing 1:1 relation.
#
## Modelfiles are ocated in spec/model.
## The exampmle runs in the test environment.
##
require 'bundler/setup'
require 'terminal-table'
require 'zeitwerk'
require 'pastel'
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
##  name -->   childre
#
#  database schema
#  CREATE DOCUMENT TYPE ex_names
#  CREATE PROPERTY ex_names.child LINK
#  CREATE PROPERTY ex_names.name STRING
#  CREATE INDEX `Example[names]` ON ex_names ( name ) UNIQUE



Ex::Names.create_type                                 # initialize the database
                                                      # spec/models/ex/names.rb
                                                      # Put same names into the database
puts "-------------------- insert data ---------------------------------"
table = %w( Guthorn Fulkerson Sniezek Tomasulo Portwine Keala Revelli Jacks Gorby Alcaoa ).map do | name |
  Ex::Names.insert name: name, age: rand(99)
end
                                                      # Connect randomly
children = (0..6).map{ | i | table[-i].rid    }
table.each{| n | n.update  child:  table[ rand(10)].rid }

puts "-------------------- raw data ---------------------------------"
puts Ex::Names.all autoload: false                    # display links as rid (do not load the document)

puts "--------------- Parent and Children ---------------------------"

## Create a Query-Object and execute it  via `query`
children_query  = Ex::Names.query projection:  ['name', 'child.name']
puts children_query.query

puts "--------------- unidirectional relation -----------------------"

## Use the `Model.all` approach instead
puts Ex::Names.all projection: ['name as parent',
                                'age as parent_age',
                                'child.age',
                                'child.child.age as second_generation_age'],
                   order: 'parent_age'


puts "-----------------  query relation - teenager -------------------"

teenager_query  = Ex::Names.query projection:  ['name as parent',
                                                'child:{name, age} as teenager'],
                                  where: 'child.age between 10 and 25'

puts teenager_query.query

__END__

Expected result

24.04.(11:12:58) INFO->Q: create document type ex_names
24.04.(11:12:58) INFO->Q: CREATE PROPERTY ex_names.child LINK
24.04.(11:12:58) INFO->Q: CREATE PROPERTY ex_names.name STRING
24.04.(11:12:58) INFO->Q: CREATE INDEX `Example[names]` ON ex_names ( name ) UNIQUE
-------------------- insert data ---------------------------------
24.04.(11:12:58) INFO->Q: INSERT INTO ex_names CONTENT {"name":"Guthorn","age":81}
24.04.(11:12:58) INFO->Q: INSERT INTO ex_names CONTENT {"name":"Fulkerson","age":16}
24.04.(11:12:58) INFO->Q: INSERT INTO ex_names CONTENT {"name":"Sniezek","age":50}
24.04.(11:12:58) INFO->Q: INSERT INTO ex_names CONTENT {"name":"Tomasulo","age":20}
24.04.(11:12:58) INFO->Q: INSERT INTO ex_names CONTENT {"name":"Portwine","age":7}
24.04.(11:12:58) INFO->Q: INSERT INTO ex_names CONTENT {"name":"Keala","age":57}
24.04.(11:12:58) INFO->Q: INSERT INTO ex_names CONTENT {"name":"Revelli","age":31}
24.04.(11:12:58) INFO->Q: INSERT INTO ex_names CONTENT {"name":"Jacks","age":23}
24.04.(11:12:58) INFO->Q: INSERT INTO ex_names CONTENT {"name":"Gorby","age":83}
24.04.(11:12:58) INFO->Q: INSERT INTO ex_names CONTENT {"name":"Alcaoa","age":58}
24.04.(11:12:58) INFO->Q: update #1:0 set child = '#2:1' return after $current
24.04.(11:12:58) INFO->Q: update #2:0 set child = '#3:0' return after $current
24.04.(11:12:58) INFO->Q: update #3:0 set child = '#1:0' return after $current
24.04.(11:12:58) INFO->Q: update #4:0 set child = '#1:1' return after $current
24.04.(11:12:58) INFO->Q: update #5:0 set child = '#2:1' return after $current
24.04.(11:12:58) INFO->Q: update #6:0 set child = '#2:1' return after $current
24.04.(11:12:58) INFO->Q: update #7:0 set child = '#8:0' return after $current
24.04.(11:12:58) INFO->Q: update #8:0 set child = '#6:0' return after $current
24.04.(11:12:58) INFO->Q: update #1:1 set child = '#4:0' return after $current
24.04.(11:12:58) INFO->Q: update #2:1 set child = '#1:1' return after $current
-------------------- raw data ---------------------------------
24.04.(11:12:58) INFO->Q: select from ex_names
<ex_names[#1:0]: age : 81, child : <ex_names[#2:1]: age : 58, child : < ex_names: #1:1 >, name : Alcaoa>, name : Guthorn>
<ex_names[#1:1]: age : 83, child : <ex_names[#4:0]: age : 20, child : < ex_names: #1:1 >, name : Tomasulo>, name : Gorby>
<ex_names[#2:0]: age : 16, child : <ex_names[#3:0]: age : 50, child : < ex_names: #1:0 >, name : Sniezek>, name : Fulkerson>
<ex_names[#2:1]: age : 58, child : <ex_names[#1:1]: age : 83, child : < ex_names: #4:0 >, name : Gorby>, name : Alcaoa>
<ex_names[#3:0]: age : 50, child : <ex_names[#1:0]: age : 81, child : < ex_names: #2:1 >, name : Guthorn>, name : Sniezek>
<ex_names[#4:0]: age : 20, child : <ex_names[#1:1]: age : 83, child : < ex_names: #4:0 >, name : Gorby>, name : Tomasulo>
<ex_names[#5:0]: age : 7, child : <ex_names[#2:1]: age : 58, child : < ex_names: #1:1 >, name : Alcaoa>, name : Portwine>
<ex_names[#6:0]: age : 57, child : <ex_names[#2:1]: age : 58, child : < ex_names: #1:1 >, name : Alcaoa>, name : Keala>
<ex_names[#7:0]: age : 31, child : <ex_names[#8:0]: age : 23, child : < ex_names: #6:0 >, name : Jacks>, name : Revelli>
<ex_names[#8:0]: age : 23, child : <ex_names[#6:0]: age : 57, child : < ex_names: #2:1 >, name : Keala>, name : Jacks>
--------------- Parent and Children ---------------------------
24.04.(11:12:58) INFO->Q: select name, child.name from ex_names
{:name=>"Guthorn", :"child.name"=>"Alcaoa"}
{:name=>"Gorby", :"child.name"=>"Tomasulo"}
{:name=>"Fulkerson", :"child.name"=>"Sniezek"}
{:name=>"Alcaoa", :"child.name"=>"Gorby"}
{:name=>"Sniezek", :"child.name"=>"Guthorn"}
{:name=>"Tomasulo", :"child.name"=>"Gorby"}
{:name=>"Portwine", :"child.name"=>"Alcaoa"}
{:name=>"Keala", :"child.name"=>"Alcaoa"}
{:name=>"Revelli", :"child.name"=>"Jacks"}
{:name=>"Jacks", :"child.name"=>"Keala"}
--------------- unidirectional relation -----------------------
24.04.(11:12:58) INFO->Q: select name as parent, age as parent_age, child.age, child.child.age as second_generation_age from ex_names order by parent_age
{:parent=>"Portwine", :parent_age=>7, :second_generation_age=>83, :"child.age"=>58}
{:parent=>"Fulkerson", :parent_age=>16, :second_generation_age=>81, :"child.age"=>50}
{:parent=>"Tomasulo", :parent_age=>20, :second_generation_age=>20, :"child.age"=>83}
{:parent=>"Jacks", :parent_age=>23, :second_generation_age=>58, :"child.age"=>57}
{:parent=>"Revelli", :parent_age=>31, :second_generation_age=>57, :"child.age"=>23}
{:parent=>"Sniezek", :parent_age=>50, :second_generation_age=>58, :"child.age"=>81}
{:parent=>"Keala", :parent_age=>57, :second_generation_age=>83, :"child.age"=>58}
{:parent=>"Alcaoa", :parent_age=>58, :second_generation_age=>20, :"child.age"=>83}
{:parent=>"Guthorn", :parent_age=>81, :second_generation_age=>83, :"child.age"=>58}
{:parent=>"Gorby", :parent_age=>83, :second_generation_age=>83, :"child.age"=>20}
-----------------  query relation - teenager -------------------
24.04.(11:12:58) INFO->Q: select name as parent, child:{name, age} as teenager from ex_names where child.age between 10 and 25
{:parent=>"Gorby", :teenager=>{:name=>"Tomasulo", :age=>20}}
{:parent=>"Revelli", :teenager=>{:name=>"Jacks", :age=>23}}

