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
