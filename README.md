#  ArcadeDB

Ruby Interface to a [Arcade Database](https://arcadedb.com/).

The program utilizes the HTTP-JSON API to direct database queries to an ArcadeDB server. 
The server's response is then mapped to an ORM (Object-Relational Mapping) based on DRY::Struct. 
Each database type is represented by a dedicated Model Class, where complex queries are encapsulated. 
The program also includes a  Query-Preprocessor for constructing custom queries in ruby fashion.

***ArcadeDB internally uses `Arcade` as primary namespace**** 

## Prerequisites

A running AracdeDB-Instance. [Quick-Start-Guide](https://docs.arcadedb.com/#Quick-Start-Docker).

## New Project

```
mkdir project && cd project
bundle init
bundle add arcadedb
bundle add pastel  # for console output
mkdir model
mkdir bin
```
copy `https://github.com/topofocus/arcadedb/blob/main/bin/console` to the `bin` directory  
copy `https://github.com/topofocus/arcadedb/blob/main/arcade.yml` to the project root and modify to your needs

## Console

To start an interactive console, a script is provided in the bin-directory.
```
$ cd bin && ./console.rb  t   ( or "d" or "p" for Test, Development and Production environment)

**in Test environment Database definitions  (model-files) of the test-suite are included!**
```

## Add to a project
Just require it in your program:
```ruby
require "arcade"
```
## Config

Add a file `arcade.yml` at the root of your program or in the `config`-dir  and  provide suitable databases for test, development and production environment.


## Examples  & Specs

The `example` directory contains documented sample files for typical usecases

The `spec`-files in the rspec-test-suite-section are worth reading, too. 

## Implementation

The adapter uses a 3 layer concept. 

Top-Layer : `Arcade::Base`-Model-Objects. 
They operate similar to ActiveRecord Model Objects but are based on [Dry-Struct](https://dry-rb.org/gems/dry-struct/1.0/).

```ruby
# Example model file  /model/demo/user.rb
module Demo
  class User < Arcade::Vertex
    attribute :name, Types::Nominal::String
    
    def grandparents
      db.query( "select in('is_family') from #{rid} ") &.allocate_model
    end
  end
end
__END__
  CREATE PROPERTY demo_user.name STRING
  CREATE INDEX on demo_user( name ) UNIQUE
```

Only the `name` attribute is declared. 

`Demo::User.create_type`  creates the type and executes provided database-commands after __END__.   

Other properties are schemaless. 

```ruby
Person.insert name: "Hubert", age: 35
Person.update set: { age: 36 }, where: { name: 'Hubert' }
persons = Person.where "age > 40"
persons.first.update age: 37
persons.first.update father: Person.create( name: 'Mike', age: 94 )

Person.all
Person.delete all: true || where: age: 56 , ...
```

### Nodes and Traverse

`ArcadeDB` wraps common queries of bidirectional connected vertices.

Suppose
```ruby 
m = Person.create name: 'Hubert', age: '25'
f = Person.create name: 'Pauline', age: '28'
m.assign via: IsMarriedTo, vertex: f , divorced: false

```
This creates the simple graph 
>  Hubert --- is_married_to --> Pauline 
>                  |
>                  -- divorced (attribute on the edge)

This can be queried through

```ruby
hubert =  Person.find name: 'Hubert'
pauline = hubert.nodes( :out, via: IsMarriedTo ).first

```
Conditions may be set, to. 
```ruby
hubert.nodes( :out, via: IsMarriedTo, where: "age < 30" )
```
gets all wives of hubert, who are younger then 30 years.  
or
```ruby
Person.nodes( :outE, via: IsMarriedTo, where: { divorced: false } )

```
gets all wives where the divorced-condition, which is set on the edge, is false. 

## Query

A **Query Preprocessor** is implemented. Its adapted from ActiveOrient. The [documentation](https://github.com/topofocus/active-orient/wiki/OrientQuery)
is still valid,  however the class has changed to `Arcade::Query`. 

The **second Layer** handles Database-Requests.  
In its actual implementation, these requests are delegated to the HTTP/JSON-API.

`Arcade::Init` uses the database specification of the `arcade.yml` file.   
The database-handle is always present through `Arcade::Init.db`

```ruby
DB =  Arcade::Init.db

$ DB.get nn, mm                                 # returns a Aracde:Base object
                                                # rid is either "#11:10:" or two numbers
$ DB.query querystring                          # returns either an Array of results (as  Hash) 
$ DB.execute { querystring }                    # execute a non idempotent query within a (nested) transaction
$ DB.create <name>, attribute: value ....       # Creates a new <Document | Vertex> and returns the rid
                                                # Operation is performed as Database-Transaction and is rolled back on error
$ DB.insert <name>, attribute: value ....       # Inserts a new <Document | Vertex> and returns the new object
$ DB.create_edge <name>, from: <rid> or [rid, rid, ..] , to: <rid> or [rid, rid, ..]

```

**Convert database input to Arcade::Base Models**

Either  `DB.query` or  `DB.execute` return the raw JSON-input from the database. It can always converted to model-objects by chaining
`allocate_model` or `select_result`.

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

The **Base Layer** implements a low level access to the database API. 

```ruby

$ Arcade::Api.databases                        # returns an array of known databases
$ Arcade::Api.create_database <a string>       # returns true if successfull
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

Simple tasks are implemented on the model layer.

### Ensure that a Record exists

The `upsert` command either updates or creates a database record.   

```ruby
  User.upsert name: 'Hugo'
  # or
  User.upsert set: { age: 46 }, where: { name: 'Hugo' }
```
either creates the record (and returns it) or returns the existing database entry. Obviously, the addressed attribute (where condition) 
must have a proper index. 

The `upsert` statement provides a smart method to ensure the presence of a defined starting point. 

### Assign Nodes to a Vertex 

Apart from accessing attributes by their method-name, adjacent edges and notes are fetched through

```ruby 
  new_vertex = ->(n) { Node.create( note_count: n )  }                      ## lambda to create a Node type record
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
  median.to_s
  -=> select median(note_count) from  ( traverse out(connects) from #52:0 while $depth < 100 )  where $depth>=50  
   =>   {:"median(note_count)"=>75.5 }
```

### Transactions

Database-Transactions are largely encapsulated

```
TestVertex.create_type
TestVertex.begin_transaction

{ perform insert, update, query, etc tasks in the database (not only the type) }

TestVertex.commit 

# or

TestVertex.rollback

```


## Contributing

Bug reports and pull requests are welcome. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the Core project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/topofocus/arcadedb/blob/master/CODE_OF_CONDUCT.md).
