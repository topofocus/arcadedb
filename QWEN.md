# ArcadeDB - Ruby Interface

## Project Overview

**ArcadeDB** is a Ruby gem that provides an ORM-like interface to the [ArcadeDB](https://arcadedb.com/) multi-model graph database. It wraps the ArcadeDB HTTP-JSON API and provides a Dry::Struct-based object modeling layer for graph operations.

### Key Features
- **Graph Database ORM**: Model vertices and edges using Dry::Struct patterns
- **Query Preprocessor**: ActiveOrient-inspired query building with SQL-like syntax
- **Match Statement Generator**: Builder pattern for complex MATCH queries
- **Traversal Support**: Navigate graph relationships with `traverse`, `nodes`, `edges` methods
- **RAG Support**: Built-in schema for vector similarity search and full-text search
- **Transaction Support**: Database transactions with rollback capabilities
- **Audit Trail**: Revision tracking with `Arcade::Revision` for audit-proof records

### Architecture
The library uses a 3-layer architecture:
1. **Model Layer** (`Arcade::Base`): Vertex/Document classes based on Dry::Struct
2. **Database Layer** (`Arcade::Database`): HTTP-JSON API wrapper
3. **API Layer** (`Arcade::Api`): Low-level database primitives

### Primary Namespace
ArcadeDB uses `Arcade` as its primary namespace. Database types are mapped to Ruby modules/classes (e.g., `Demo::User < Arcade::Vertex`).

## Technologies

- **Ruby** (gem)
- **ArcadeDB** (graph database backend)
- **Dry::Struct**, **Dry::Schema**, **Dry::Configurable** (data structures)
- **HTTPX** (HTTP client)
- **RSpec** (testing framework)

## Building and Running

### Prerequisites
- Ruby 2.7+ (implied by modern syntax)
- A running ArcadeDB instance (see [Quick-Start Guide](https://docs.arcadedb.com/#Quick-Start-Docker))

### Installation
```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run default task (RSpec)
rake
```

### Starting ArcadeDB Server
```bash
# Using Docker (recommended)
docker run -p 2480:2480 -p 2424:2424 arcadedb/arcadedb:latest
```

### Interactive Console
```bash
# Start console with environment (t=test, d=development, p=production)
./bin/console t
```

### Configuration
Create `arcade.yml` in project root or `config/` directory:
```yaml
:environment:
  :test:
    dbname: playground
    user: root
    pass: your_password
    w mfix 
  :development:
    dbname: devel
    user: root
    pass: your_password
:admin:
  :host: localhost
  :port: 2480
  :user: root
  :pass: your_password
:logger: stdout
:namespace: Arcade
:autoload: true
```

## Development Conventions

### Code Style
- Follows Ruby conventions for gem development
- Uses Dry.rb ecosystem patterns (Dry::Struct, Dry::Configurable)
- Module-based organization with snake_case naming for database types

### File Structure
```
lib/
  arcade.rb              # Main entry point
  arcade/
    base.rb              # Core Arcade::Base class
    database.rb          # Database adapter
    api/                 # Low-level API primitives
    support/             # Helper modules (Sql, Model, Conversions)
    match.rb             # MATCH query builder
    query.rb             # Query preprocessor
    init.rb              # Connection initialization
    rag_schema.rb        # RAG schema support
  model/                 # Example model definitions
  types.rb               # Dry::Types definitions

spec/                    # RSpec test suite
examples/                # Usage examples
bin/                     # Console scripts
```

### Testing
- RSpec-based test suite in `spec/` directory
- Test models in `spec/model/`
- Database helper in `spec/database_helper.rb`
- Run with: `bundle exec rspec`

### Adding a New Model
```ruby
module MyModule
  class MyModel < Arcade::Vertex
    attribute :name, Types::String

    def self.db_init
      # Custom database initialization
    end
  end
end

# Create database type
MyModule::MyModel.create_type
```

## Key APIs

### Basic CRUD
```ruby
# Create
MyModel.create(name: "John", age: 30)

# Read
MyModel.where("age > 25")
MyModel.find(name: "John")

# Update
MyModel.update(set: { age: 31 }, where: { name: "John" })

# Delete
MyModel.delete(where: { age: 30 })

# Upsert
MyModel.upsert(name: "John")
```

### Graph Operations
```ruby
# Create edges
vertex.assign(via: EdgeType, vertex: other_vertex)

# Traverse
vertex.nodes(:out, via: EdgeType)
vertex.edges.to_human

# Complex traversal
vertex.traverse(:out, via: EdgeType, depth: 100)
```

### Query Building
```ruby
# Using Query class
query = Arcade::Query.new(
  from: MyModel,
  projection: 'count(*)',
  where: 'age > 25'
)
query.execute

# Using Match builder
match = Arcade::Match.new(type: Person, as: :persons)
      .out(IsMarriedTo)
      .node(where: 'age < 30')
match.execute.select_results
```

### RAG (Vector Search)
```ruby
class Document < Arcade::Vertex
  include Arcade::RAGSchema
  attribute :content, Types::String
  attribute :embedding?, Types::Array.of(Types::Float).optional
end

# Vector similarity search
Document.vector_search(embedding, limit: 10, threshold: 0.7)

# Hybrid search (vector + full-text)
Document.hybrid_search(embedding, "query text", limit: 10)
```

## Examples

See the `examples/` directory for complete working examples:
- `books.rb` - Book collection example
- `rag_example.rb` - RAG schema usage
- `relation_1__1.rb` - One-to-one relationships
- `relation_1__n.rb` - One-to-many relationships
- `relation_n_n.rb` - Many-to-many relationships

## Documentation Resources

- [ArcadeDB Documentation](https://docs.arcadedb.com/)
- [Query Preprocessor Docs](https://github.com/topofocus/active-orient/wiki/OrientQuery) (still valid)
- [Match Statement Docs](https://github.com/ArcadeData/arcadedb-docs/blob/main/src/main/asciidoc/sql/SQL-Match.adoc)

## Contributing

Bug reports and pull requests are welcome. See `CHANGELOG.md` for version history.

### Code of Conduct
Contributors should adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

MIT License (see LICENSE file)
