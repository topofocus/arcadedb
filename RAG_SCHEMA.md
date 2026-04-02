# RAG Schema Module

A module to implement a RAG (Retrieval-Augmented Generation) compatible database schema for ArcadeDB.

## Overview

The `Arcade::Ragschema` module provides a default-index configuration optimized for:
- **Vector similarity search** (semantic embeddings)
- **Metadata filtering**

## Installation

The module is included in the gem and automatically available when you require `arcade`.

## Usage

### Basic Setup

```ruby
require 'arcade'

module MyApp
  class Document < Arcade::Vertex
    include Arcade::Ragschema

    attribute :content, Types::String
    attribute :embedding?, Types::Array.of(Types::Float).optional
    attribute :metadata?, Types::Hash.optional
  end
end

# Create the database type with RAG indexes
MyApp::Document.create_type
```

### Custom Schema Configuration

```ruby
module MyApp
  class Document < Arcade::Vertex
    include Arcade::Ragschema

    attribute :content, Types::String
    attribute :embedding?, Types::Array.of(Types::Float).optional
    attribute :title?, Types::String.optional
    attribute :metadata?, Types::Hash.optional

    def self.db_init
      # Custom schema with 768-dimensional embeddings
      rag_db_init(vector_dimension: 768)
    end
  end
end
```

### Inserting Documents with Embeddings

```ruby
# Generate embedding using your preferred service (OpenAI, HuggingFace, etc.)
embedding = generate_embedding("Your text content here")

doc = MyApp::Document.create(
  content: "The content of your document",
  embedding: embedding,
  metadata: {
    author: "John Doe",
    tags: ["ruby", "database"],
    category: "technical"
  },
  source_url: "https://example.com/document",
  created_at: DateTime.now
)
```

### Vector Similarity Search

Perform semantic search using vector embeddings:

```ruby
# Generate embedding for the query
query_embedding = generate_embedding("What is a graph database?")

# Search for similar documents
results = MyApp::Document.vector_search(
  query_embedding,
  limit: 10,        # Maximum number of results
  threshold: 0.7    # Minimum similarity score (0.0 to 1.0)
)

results.each do |doc|
  puts "#{doc[:content]} (similarity: #{doc[:similarity]})"
end
```

### Hybrid Search

Combine vector similarity with SQL LIKE text filtering:

```ruby
query_embedding = generate_embedding("graph database")

results = MyApp::Document.hybrid_search(
  query_embedding,
  "Ruby programming",  # SQL LIKE search term
  limit: 10,
  vector_threshold: 0.7
)
```

### Instance Method

You can also call `vector_search` on an instance (delegates to class method):

```ruby
doc = MyApp::Document.first
results = doc.vector_search(query_embedding, limit: 5)
```

## Schema Details

The RAG schema creates the following properties and indexes:

### Properties
- `embedding` - ARRAY_OF_FLOATS type for vector storage
- `content` - STRING for full document content
- `metadata` - MAP for flexible metadata
- `source_url` - STRING for source tracking
- `created_at` - DATETIME for timestamp

### Indexes
- **LSM_VECTOR** index on `embedding` for similarity search with COSINE similarity
- **LSM_TREE** index on `metadata` for filtering

## Configuration Options

### `rag_db_init` Options

| Option | Default | Description |
|--------|---------|-------------|
| `vector_dimension` | 1536 | Dimension of vector embeddings (OpenAI default) |

### `vector_search` Options

| Option | Default | Description |
|--------|---------|-------------|
| `limit` | 10 | Maximum number of results to return |
| `threshold` | 0.7 | Minimum similarity score (0.0-1.0) |

### `hybrid_search` Options

| Option | Default | Description |
|--------|---------|-------------|
| `limit` | 10 | Maximum number of results |
| `vector_threshold` | 0.7 | Minimum vector similarity score |

## API Reference

### `rag_schema(vector_dimension:)`

Returns the SQL commands for creating RAG indexes.

```ruby
schema = MyApp::Document.rag_schema(vector_dimension: 768)
# => "CREATE INDEX ON my_document (embedding) LSM_VECTOR METADATA {dimensions: 768, similarity: 'COSINE'}\n..."
```

### `rag_db_init(vector_dimension:)`

Returns the SQL commands for creating properties and indexes. This is typically called from `db_init`.

```ruby
sql = MyApp::Document.rag_db_init(vector_dimension: 768)
```

### `.vector_search(query_embedding, limit:, threshold:)`

Perform vector similarity search across all documents. Returns metadata only (not embedding vectors) for efficiency.

```ruby
results = MyApp::Document.vector_search(query_embedding, limit: 10, threshold: 0.7)
# Returns: Array of Hashes with :title, :content, :category, :similarity, etc.
```

### `.hybrid_search(query_embedding, text_query, limit:, vector_threshold:)`

Perform hybrid search combining vector similarity with SQL LIKE text filtering.

```ruby
results = MyApp::Document.hybrid_search(query_embedding, "search terms", limit: 10, vector_threshold: 0.7)
```

### `#vector_search(query_embedding, limit:, threshold:)`

Instance method that delegates to the class method.

```ruby
doc = MyApp::Document.first
results = doc.vector_search(query_embedding, limit: 5)
```

## Limitations

### Full-Text Search

**Full-text search is not yet implemented.** The `FULLTEXT` index type is not supported in the current ArcadeDB server version. 

For text filtering, use the `hybrid_search` method which uses SQL `LIKE` pattern matching instead:

```ruby
# Instead of full-text search, use LIKE-based filtering
results = MyApp::Document.hybrid_search(
  query_embedding,
  "search term",  # Uses: content LIKE '%search term%'
  limit: 10
)
```

Future versions may add support for:
- Apache Lucene-based full-text indexes
- Tokenization and stemming
- Relevance scoring

## Example

See `examples/rag_usecase_demo.rb` for a complete working example.

## Requirements

- ArcadeDB server with vector search support (version 23.12+)
- External embedding service (OpenAI, HuggingFace, etc.) for generating embeddings

## Testing

Run the RAG schema tests:

```bash
bundle exec rspec spec/lib/rag_schema_spec.rb
bundle exec rspec spec/lib/usecase/rag_integration_spec.rb
```
