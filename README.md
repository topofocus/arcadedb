#  ArcadeDB

Ruby Interface to a [Arcade Database](https://arcadedb.com/).

> This ist a pre alpha version with minimal functionality. 

The adapter accesses the HTTP-Json-Api of ArcadeDB.

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

## Usage

Actually, only a basic HTTP-APi-Access is implemented.

It allows to play around using simple api-calls:
```ruby

$ Arcade::Api.databases                   # returns an array of known databases
$ Arcade::Api.create_database <a string>  # returns true if succesfull
$ Arcade::Api.drop_database   <a string>  # returns true if successfull

$ Arcade::Api.create_document <database>, <type>,  attribute: value , ...
$ Arcade::Api.get_record <database>,  rid  #  returns a hash

$ Arcade::Api.execute( <database>  ) { <query>  }
$ Arcade::Api.query( <database>  ) { <query>  }
```


`<query>` is  either a  string or   
a hash  ` { :query => " ", `
			`:language => one of :sql, :cypher, :gmelion: :neo4j ,` 
			`:params =>   a  hash of parameters,` 
			`:limit => a number ,`
			`:serializer:  one of :graph, :record }`



## Contributing

Bug reports and pull requests are welcome. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the Core project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/topofocus/arcadedb/blob/master/CODE_OF_CONDUCT.md).
