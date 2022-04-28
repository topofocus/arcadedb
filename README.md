#  ArcadeDB

Ruby Interface to a [Arcade Database](https://arcadedb.com/).

> This ist an alpha version. 

The adapter implements the HTTP-JSON-Api of ArcadeDB.

***ArcadeDB internally uses `Arcade` as primary namespace**** 

## Prerequisites

A running AracdeDB-Instance. [Quick-Start-Guide](https://docs.arcadedb.com/#Quick-Start-Docker).

## Config

Edit the file `config.yml`  and  provide suitable databases for test, development and production environment.

For Access through the HTTP-API `:admin`-entries are used. 

## Console

To start an interactive console, a small script is provided in the bin-directory.
```
$ cd bin && ./console.rb  t   ( or "d" or "p" for Test, Development and Production environment)
```

## Examples

The `example` directory contains documented sample files for typical usecases

## Implementation

The adapter uses a 3 layer concept. 

Top-Layer : `Arcade::Base`-Model-Objects. 
They operate similar to ActiveRecord Model Objects.

```ruby
# Assuming, a Database-Type Person is present
Person.create name: "Hubert" age: 35
Person.update set: { age: 36 }, where: { name: 'Hubert' }
persons = Person.where "age > 40"
persons.first.update age: 37

Person.all
Person.delete all: true || where: age: 56 , ...
```
Model-Classes have to be declared in the model directory. Namespaces are supported. 
Model-attributes are taken from [Dry-types](https://dry-rb.org/gems/dry-types/1.2/built-in-types/).

Database [Properties](https://docs.arcadedb.com/#SQL-Create-Property) and [Indexes](https://docs.arcadedb.com/#SQL-Create-Index) are declared in the model file. [Example](https://github.com/topofocus/arcadedb/blob/main/spec/model/node.rb)
If the model based type-initialisation is used
the commands are processed after creating the database-type.
```ruby
My::Names.create_type                          # create tyoe for class Names < Arcade::Vertex 
```


A **Query Preprocessor** is implemented. Its adapted from ActiveOrient. The [documentation](https://github.com/topofocus/active-orient/wiki/OrientQuery)
is still valid,  however the class has changed to `Arcade::Query`. 

The **second Layer** handles Database-Requests.  
In the actual implementation, these requests are delegated to the HTTP/JSON-API.

`Arcade::Init` uses the database specification of the `config.yml` file.   
The database-handle is always present through `Arcade::Init.db`

```ruby
DB =  Arcade::Init.db

$ DB.get <rid> || nn, mm                        # returns a Aracde:Base object
                                                # rid is either "#11:10:" or two numbers
$ DB.query querystring                          # returns either an Array of results (as  Hash) 
$ DB.execute { querystring }                    # 
$ DB.create <name>, attribute: value ....       # Creates a new <Document | Vertex> and returns the rid
                                                # Operation is performed as Database-Transaction and is rolled back on error
$ DB.insert <name>, attribute: value ....       # Inserts a new <Document | Vertex> and returns the rid
$ DB.create_edge <name>, from: <rid> or [rid, rid, ..] , to: <rid> or [rid, rid, ..]

DB.query " Select from person where age > 40 "
DB.execute { " Update person set name='Hubert' return after $current where age = 36 " }
```

**Convert database input to Arcade::Base Models**

Either  `DB.query` or  `DB.execute` return the raw JSON-input from the database. It can always converted to model-objects by chaining
`allocatet_model`.

```ruby
$ DB.query "select from my_names limit 1"
# which is identical to
$ My::Names.query( limit: 1).query
 => [{:@out=>0, :@rid=>"#225:6", :@in=>0, :@type=>"my_names", :@cat=>"v", :name=>"Zaber"}] 
# then
$ My::Names.query( limit: 1).query.allocate_model.to_human
 => ["<my_names[#225:6]: name: Zaber>" ]
 # replaces the hash with a My::Names Object 
```

The **third Layer** implements the direct interaction with the database API. 

```ruby

$ Arcade::Api.databases                        # returns an array of known databases
$ Arcade::Api.create_database <a string>       # returns true if succesfull
$ Arcade::Api.drop_database   <a string>       # returns true if successfull

$ Arcade::Api.begin_transaction <database>
$ Arcade::Api.create_document <database>, <type>,  attribute: value , ...
$ Arcade::Api.execute( <database>  ) { <query>  }
$ Arcade::Api.commit <database>                #  or Arcade::Api.rollback  


$ Arcade::Api.query( <database>  ) { <query>  }
$ Arcade::Api.get_record <database>,  rid      #  returns a hash
```


`<query>` is  either a  string or   a hash: 
```ruby 
{  :query      => "<the query string> ",
   :language   => one of :sql, :cypher, :gmelin: :neo4 ,
	 :params     =>   a  hash of parameters,
	 :limit      => a number ,
	 :serializer =>  one of :graph, :record }    
```	   

## ORM Behavior

Simple tasks are implemented on the model layer. a

### Ensure that a Record exists

The `upsert` command either updates or creates a database record.   

```ruby
  User.upsert name: 'Hugo'
  # or
  User.upsert set: { age: 46 }, where: { name: 'Hugo' }
```
either creates the record (and returns it) or returns the existing database entry. Obviously, the addressed attribute (where condition) 
must have a proper index. 

The `upsert` statement provides a smart method to ensure the presence of an unique starting point. 

### Assign Nodes to a Vertex 

Apart from assessing attributes by their method-name, adjacent edges and notes are fetched through

```ruby 
  new_vertex = ->(n) { Node.insert( note_count: n )  }                      ## lambda to create a Node type record
  nucleus    =  BaseNode.create item: 'b'                                   ## create a start node
  (1..10).each{ |n| nucleus.assign( via: Connects, vertex: new_vertex[n]) } ## connect nodes via Connects-Edges
```
After creating a star-like structure, the environment can be explored 
```ruby 
  nucleus.edges.to_human
  =>["<connects[#80:14] :.: #4:0->{}->#34:2>",                                  
     "<connects[#79:13] :.: #4:0->{}->#31:1>",                                  
     ( ... )
     "<connects[#79:14] :.: #4:0->{}->#31:2>"] 

   nucleus.nodes.to_human
 => ["<node[#34:2]: item: 10>",                                                         
     "<node[#31:1]: item: 1>",                                                          
     ( ... )
     "<node[#31:2]: item: 9>"]    
```

Edges provide a `vertices`-method to load connected ones.  Both vertices and edges expose `in`, `out`,  `both`-methods to select connections further. 
Specific edge-classes (types) are provided with the `via:` parameter,  as shown in `assign` above. 


### Traverse Facility

To ease queries to the graph database, `Arcade::Query` supports traversal of nodes

Create a Chain of Nodes:
```ruby

  def linear_elements start, count  #returns the edge created
      new_vertex = ->(n) { Arcade::ExtraNode.create( note_count: n )  }
      (2..count).each{ |n| start = start.assign vertex: new_vertex[n], via: Arcade::Connects  }
  end
   
  start_node =  Arcade::ExtraNode.create( item: 'linear'  )
  linear_elements start_node , 200
```

Select a range of nodes and perform a mathematical operation

```ruby 
  hundred_elements =  start_node.traverse :out, via: Arcade::Connects, depth: 100
  median = Query.new from: hundred_elements,
               projection: 'median(note_count)',
                    where: '$depth>=50'
  meian.to_s
  -=> select median(note_count) from  ( traverse out(connects) from #52:0 while $depth < 100 )  where $depth>=50  
   =>   {:"median(note_count)"=>75.5 }
```
## Include in your own project

Until a gem is released, first clone the project and set up your project environment
```
mkdir workspace && cd workspace
git clone https://github.com/topofocus/arcadedb
mkdir my-project && cd my-project
bundle init
cat "gem arcadedb, path='../arcadedb' " >> Gemfile
bundle install && bundle upate
cp ../arcadedb/config.yml .
mkdir bin
cp ../arcadedb/bin/console bin/
````


## Contributing

Bug reports and pull requests are welcome. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the Core project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/topofocus/arcadedb/blob/master/CODE_OF_CONDUCT.md).
