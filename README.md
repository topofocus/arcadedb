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
$ cd bin && ./console.rb 
```
## Implementation

The adapter uses a 3 layer concept. 

The Top-Layer : `Arcade::Base`-Model-Objects. 
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

A Query Proprocessor is implemented. Its adapted from ActiveOrient. The [documentation](https://github.com/topofocus/active-orient/wiki/OrientQuery)
is still valid,  however the class has changed to `Arcade::Query`. 

The second Layer handles Database-Requests.  
In the actual implementation, these requests are delegated to the HTTP/JSON-API.

`Arcade::Init` uses the database specification of the `config.yml` file.   
The database-handle is always present through `Arcade::Init.db`

```ruby
DB =  Arcade::Init.db

$ DB.get <rid>                                  # returns a Aracde:Base object
$ DB.query querystring                          # returns either an Array of results (as  Hash) 
$ DB.execute { querystring }                    # or a Collection of Arcade::Base objects

$ DB.create_type {document | vertex} , <name>   # Creates a new Type ( Arcade::Base Class)
$ DB.create <name>, attribute: value ....       # Creates a new <Document | Vertex> and returns the rid
$ DB.create_edge <name>, from: <rid> or [rid, rid, ..] , to: <rid> or [rid, rid, ..]

DB.query " Select from person where age > 40 "
DB.execute { " Update person set name='Hubert' return after $current where age = 36 " }
```

The third Layer implements the direct interaction with the database API. 

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


`<query>` is  either a  string or   
a hash  ` { :query => " ", `  
			`:language => one of :sql, :cypher, :gmelion: :neo4j ,`   
			`:params =>   a  hash of parameters,`   
			`:limit => a number ,`  
			`:serializer:  one of :graph, :record }`  



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
