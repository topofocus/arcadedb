# Changelog

All notable changes to this project will be documented in this file.



## 0.3.1 - 2023-01-16

- Integration into the Bridgetown Environment 

## 0.3.3 - 2023.04.23
- Support for embedded Dokuments and Maps
- iruby support 

## 0.4.0 - 2023.10.28
- completely remove pg-stuff
- substitute typhoreous with  HTTPX

## 0.4.1 - 2023.10.31
- redesign of transactions. 
- Type.execute performs non idempotent queries  in a (nested) transaction
- Type.transmit performs non idempotent queries 
- Type.query performs idempotent queries 
- Type.create returns a rid
- Type.insert returns a type-object
- Vertex.nodes supports conditions on edges
- Vertex.in, Vertex.out Vertex.inE, Vertex.outE support depth as second parameter
- IRuby-Support. Formatted output for Base-Objects

## 0.5.0 - 2023-12-12
- Arcade::Match simple match-statement generator
- return to Arcade::QueryError messages instead of HTTPX::HTTPError
- The ProjectRoot Const is used to read configuration files (Changed from Arcade::ProjectRoot)

## 0.5.1 - 2024-1-16
- Included Arcade::RevisionRecord and Arcade::Revision model classes
- Both provide basic support for audit proofed bookings
##       - 2025-02-11
- Include method Object#descendants (part of active-support)
- Separate Dry::Type definitions to /lib/types.rb
- added Vertex#coe (count of edeges) as service method for to_human
- updated Match#inE, #outE methods to facilitate queries on properties on edges
##       - 2025-03-15
- support of Match.new vertex: {a prefetched Arcade::Vertex} and match.node( vertex: ...) 
##       - 2025-03-25
- support of Vertex.match( where conditions [, as: :return_element] )
- added Vertex#match to build  'MATCH type: {class} rid: {rid}'



