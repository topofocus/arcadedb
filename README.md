#  ArcadeDB

Ruby Interface to a [Arcade Database](https://arcadedb.com/).

> This ist a pre alpha version. 

The adapter implements the HTTP-JSON-Api of ArcadeDB.

It aims to enable
* to create and destroy databases 
* to submit database-queries

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

## Database Management

The console allows a low-level management of the database-server
It allows to play around using simple api-calls:
```ruby

$ Arcade::Api.databases                   # returns an array of known databases
$ Arcade::Api.create_database <a string>  # returns true if succesfull
$ Arcade::Api.drop_database   <a string>  # returns true if successfull

$ Arcade::Api.begin_transaction <database>
$ Arcade::Api.create_document <database>, <type>,  attribute: value , ...
$ Arcade::Api.execute( <database>  ) { <query>  }
$ Arcade::Api.commit <database>         #  or Arcade::Api.rollback  


$ Arcade::Api.query( <database>  ) { <query>  }
$ Arcade::Api.get_record <database>,  rid  #  returns a hash
```


`<query>` is  either a  string or   
a hash  ` { :query => " ", `  
			`:language => one of :sql, :cypher, :gmelion: :neo4j ,`   
			`:params =>   a  hash of parameters,`   
			`:limit => a number ,`  
			`:serializer:  one of :graph, :record }`  


## Database Operations

The `Database`-Class connects to the standard database as specified in the `config.yml` file. It returns `Arcade::Base`-Objects if apropiate.


```ruby
DB =  Aracde::Database.new {:development | :production | :test}

```
Simple commands are implemented on this level

```ruby

$ DB.get <rid>                                  # returns a Aracde:Base object
$ DB.query querystring                          # returns either an Array of results (as  Hash) 
                                                # or a Collection of Arcade::Base objects

$ DB.create_type {document | vertex} , <name>   # Creates a new Type ( Arcade::Base Class)
$ DB.create <name>, attribute: value ....       # Creates a new <Document | Vertex> and returns the rid
$ DB.create_edge <name>, from: <rid> or [rid, rid, ..] , to: <rid> or [rid, rid, ..]


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
