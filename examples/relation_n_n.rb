##
## This example realises a bidirectional 1:n relation using Edges & Vertices
#
## The schema is implemented in modelfiles located in spec/model
## /spec/models/ex/human.rb             #  Vertex
## /spec/models/ex/depend_on.rb         #  Edge
#
#  This script runs in the test environment.
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
## parent  <-->   children
#


Ex::Human.create_type                                                             # initialize the database
Ex::DependOn.create_type

nodes = %w( Guthorn Fulkerson Sniezek Tomasulo Portwine Keala Revelli Jacks Gorby Alcaoa ).map do | name |
  Ex::Human.insert name: name, birth: 2022 - rand(99), married: rand(2)==1
end

puts Ex::Human.count.to_s + " Human Vertices created"

puts "------------------------------ get a sorted list of married humans ---------------------------------"
puts

merried = Ex::Human.query( where: { married: true })
merried.order 'birth'
new_merried = Query.new projection: 'name, 2022-birth as age ', from: merried          #  merge two queries
puts new_merried.query

puts "------------------------------ and one for not married humans      ---------------------------------"
puts

singles = Ex::Human.query( where: { married: false })
singles.order 'birth'
new_singles = Query.new projection: 'name, 2022-birth as age ', from: singles          #  merge two queries
puts new_singles.query


puts "------------------------------ connect  married humans  with children ------------------------------"
children = singles.query.allocate_model

begin
  children_enumerator =  children.each
  merried.query.allocate_model.map do | parent |
    parent.assign via: Ex::DependOn, vertex: children_enumerator.next
  end
rescue StopIteration
   puts "No more children"
end

# Ex::Human.parents is essential
#    EX::Human.query projection: 'out()' , whee: { married: true }
# Ex::Human.children is essential
#    EX::Human.query projection: 'out()' , whee: { married: true }
puts "--------------------------- Parent and Children ---------------------------------------------------"
puts
puts "%10s  %7s %10s %30s " % ["Parent", "Age", "Child", "sorted by Child"]
puts "- " * 50
Ex::Human.parents( order: 'name' ).each  do |parent|                          # note: order: 'name' is included
                                                                              # in the query, but has no effect 
  puts "%10s  %7d %10s  " % [parent.name, 2022 - parent.birth, parent.out.first.name] 
end

puts "--------------------------- child and parent  -----------------------------------------------------"
puts
puts "%10s  %7s %10s %30s " % ["Child", "Age", "Parent", "sorted by Parent"]
puts "- " * 50
Ex::Human.children( order: 'name' ).each  do |child|
  puts "%10s  %7d %10s  " % [child.name, 2022 - child.birth, child.in.first.name] 
end

puts "--------------------------- Add  child to a parent  -----------------------------------------------"
puts

Ex::Human.parents.first.assign via: Ex::DependOn, vertex:  Ex::Human.insert( name: "TestBaby", birth: 2022, married: false)

puts "Parent: " +  Ex::Human.parents.first.to_human
puts "Children: \n " + Ex::Human.parents.first.out.to_human.join("\n ")

## Expected output
__END__

Using default database credentials and settings fron /home/ubuntu/workspace/arcadedb
27.04.(18:35:05) INFO->Q: create vertex type ex_human 
27.04.(18:35:05) INFO->Q: CREATE PROPERTY ex_human.name STRING
27.04.(18:35:05) INFO->Q: CREATE PROPERTY ex_human.married BOOLEAN
27.04.(18:35:05) INFO->Q: CREATE INDEX `Example[human]` ON ex_human ( name  ) UNIQUE
27.04.(18:35:05) INFO->Q: create edge type ex_depend_on 
27.04.(18:35:05) INFO->Q: CREATE INDEX depends_out_in ON ex_depend_on  (`@out`, `@in`) UNIQUE
27.04.(18:35:05) INFO->Q: INSERT INTO ex_human CONTENT {"name":"Guthorn","birth":1962,"married":false} 
27.04.(18:35:05) INFO->Q: INSERT INTO ex_human CONTENT {"name":"Fulkerson","birth":1962,"married":true} 
27.04.(18:35:05) INFO->Q: INSERT INTO ex_human CONTENT {"name":"Sniezek","birth":1972,"married":true} 
27.04.(18:35:05) INFO->Q: INSERT INTO ex_human CONTENT {"name":"Tomasulo","birth":1953,"married":false} 
27.04.(18:35:05) INFO->Q: INSERT INTO ex_human CONTENT {"name":"Portwine","birth":1975,"married":true} 
27.04.(18:35:05) INFO->Q: INSERT INTO ex_human CONTENT {"name":"Keala","birth":1961,"married":false} 
27.04.(18:35:05) INFO->Q: INSERT INTO ex_human CONTENT {"name":"Revelli","birth":1948,"married":true} 
27.04.(18:35:05) INFO->Q: INSERT INTO ex_human CONTENT {"name":"Jacks","birth":1993,"married":true} 
27.04.(18:35:05) INFO->Q: INSERT INTO ex_human CONTENT {"name":"Gorby","birth":1979,"married":false} 
27.04.(18:35:05) INFO->Q: INSERT INTO ex_human CONTENT {"name":"Alcaoa","birth":1960,"married":false} 
27.04.(18:35:05) INFO->Q: select count(*) from ex_human 
10 Human Vertices created
------------------------------ get a sorted list of married humans ---------------------------------

27.04.(18:35:05) INFO->Q: select name, 2022-birth as age  from  ( select from ex_human where married = true order by birth  )  
{:name=>"Revelli", :age=>74}
{:name=>"Fulkerson", :age=>60}
{:name=>"Sniezek", :age=>50}
{:name=>"Portwine", :age=>47}
{:name=>"Jacks", :age=>29}
------------------------------ and one for not married humans      ---------------------------------

27.04.(18:35:05) INFO->Q: select name, 2022-birth as age  from  ( select from ex_human where married = false order by birth  )  
{:name=>"Tomasulo", :age=>69}
{:name=>"Alcaoa", :age=>62}
{:name=>"Keala", :age=>61}
{:name=>"Guthorn", :age=>60}
{:name=>"Gorby", :age=>43}
------------------------------ connect  married humans  with children ------------------------------
27.04.(18:35:05) INFO->Q: select from ex_human where married = false order by birth
27.04.(18:35:05) INFO->Q: select from ex_human where married = true order by birth
27.04.(18:35:05) INFO->Q: create edge ex_depend_on from #19:0 to #10:0 CONTENT {"set":{}}
27.04.(18:35:05) INFO->Q: create edge ex_depend_on from #4:0 to #4:1 CONTENT {"set":{}}
27.04.(18:35:05) INFO->Q: create edge ex_depend_on from #7:0 to #16:0 CONTENT {"set":{}}
27.04.(18:35:05) INFO->Q: create edge ex_depend_on from #13:0 to #1:0 CONTENT {"set":{}}
27.04.(18:35:05) INFO->Q: create edge ex_depend_on from #22:0 to #1:1 CONTENT {"set":{}}
--------------------------- Parent and Children ---------------------------------------------------

      Parent      Age      Child                sorted by Child 
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
27.04.(18:35:05) INFO->Q: select in() from ex_human where married = false order by name
27.04.(18:35:05) INFO->Q: select out() from #4:0 
Fulkerson       60     Alcaoa  
27.04.(18:35:05) INFO->Q: select out() from #22:0 
Jacks       29      Gorby  
27.04.(18:35:05) INFO->Q: select out() from #13:0 
Portwine       47    Guthorn  
27.04.(18:35:05) INFO->Q: select out() from #7:0 
Sniezek       50      Keala  
27.04.(18:35:05) INFO->Q: select out() from #19:0 
Revelli       74   Tomasulo  
--------------------------- child and parent  -----------------------------------------------------

  Child      Age     Parent               sorted by Parent 
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
27.04.(18:35:05) INFO->Q: select out() from ex_human where married = true order by name
27.04.(18:35:05) INFO->Q: select in() from #4:1 
Alcaoa       62  Fulkerson  
27.04.(18:35:05) INFO->Q: select in() from #1:1 
Gorby       43      Jacks  
27.04.(18:35:05) INFO->Q: select in() from #1:0 
Guthorn       60   Portwine  
27.04.(18:35:05) INFO->Q: select in() from #10:0 
Tomasulo       69    Revelli  
27.04.(18:35:05) INFO->Q: select in() from #16:0 
Keala       61    Sniezek  
--------------------------- Add  child to a parent  -----------------------------------------------

27.04.(18:35:05) INFO->Q: select in() from ex_human where married = false 
27.04.(18:35:05) INFO->Q: INSERT INTO ex_human CONTENT {"name":"TestBaby","birth":2022,"married":false} 
27.04.(18:35:05) INFO->Q: create edge ex_depend_on from #13:0 to #7:1 CONTENT {"set":{}}
27.04.(18:35:05) INFO->Q: select in() from ex_human where married = false 
Parent: <ex_human[#13:0]: {0->}{->2}}, birth: 1975, married: true, name: Portwine>
27.04.(18:35:05) INFO->Q: select in() from ex_human where married = false 
27.04.(18:35:05) INFO->Q: select out() from #13:0 
Children: 
 <ex_human[#1:0]: {->}{->}}, birth: 1962, married: false, name: Guthorn>
 <ex_human[#7:1]: {->}{->}}, birth: 2022, married: false, name: TestBaby>


