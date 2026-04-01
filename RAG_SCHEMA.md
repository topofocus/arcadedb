# RAG Schema Module

A generic class to implement a RAG (Retrieval-Augmented Generation) compatible database schema for ArcadeDB.

## Overview

The `Arcade::RAGSchema` module provides a default-index configuration optimized for:
- **Vector similarity search** (semantic embeddings)
- **Full-text search** (keyword matching)
- **Metadata filtering**

## Installation

The module is included in the gem and automatically available when you require `arcade`.

## Usage

### Basic Setup

```ruby
require 'arcade'

module MyApp
  class Document < Arcade::Vertex
    include Arcade::RAGSchema
    
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
    include Arcade::RAGSchema
    
    attribute :content, Types::String
    attribute :embedding?, Types::Array.of(Types::Float).optional
    attribute :title?, Types::String.optional
    attribute :metadata?, Types::Hash.optional

    def self.db_init
      # Custom schema with 768-dimensional embeddings and multiple full-text fields
      rag_db_init(
        vector_dimension: 768,
        full_text_fields: ['content', 'title']
      )
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
  puts "#{doc.content} (similarity: #{doc.similarity})"
end
```

### Hybrid Search

Combine vector similarity with full-text search:

```ruby
query_embedding = generate_embedding("graph database")

results = MyApp::Document.hybrid_search(
  query_embedding,
  "Ruby programming",  # Full-text query
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
- `embedding` - EMBEDDED type for vector storage
- `content` - TEXT for full document content
- `metadata` - EMBEDDED for flexible metadata
- `source_url` - STRING for source tracking
- `created_at` - DATETIME for timestamp

### Indexes
- **FULLVECTOR** index on `embedding` for similarity search
- **FULLTEXT** index on specified text fields
- **NOTUNIQUE** index on `metadata` for filtering

## Configuration Options

### `rag_db_init` Options

| Option | Default | Description |
|--------|---------|-------------|
| `vector_dimension` | 1536 | Dimension of vector embeddings (OpenAI default) |
| `full_text_fields` | `['content']` | Array of fields to index for full-text search |

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

## Example

See `examples/rag_example.rb` for a complete working example.

## Requirements

- ArcadeDB server with vector search support (version 23.12+)
- External embedding service (OpenAI, HuggingFace, etc.) for generating embeddings

## Testing

Run the RAG schema tests:

```bash
bundle exec rspec spec/lib/rag_schema_spec.rb
```
