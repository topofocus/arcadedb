# RAG (Retrieval-Augmented Generation) Example
# 
# This example demonstrates how to use the Arcade::RAGSchema module
# to create a RAG-compatible document store with vector embeddings.
#
# Prerequisites:
# - A running ArcadeDB server with vector search support
# - An embedding service (e.g., OpenAI, HuggingFace) to generate embeddings
#
# Setup:
#   1. Create a model that includes Arcade::RAGSchema
#   2. Call create_type to set up the database schema
#   3. Insert documents with their embeddings
#   4. Perform vector or hybrid search

require 'bundler/setup'
require 'arcade'

# Example model definition
module RAG
  class Document < Arcade::Vertex
    include Arcade::RAGSchema
    
    attribute :content, Types::String
    attribute :embedding?, Types::Array.of(Types::Float).optional
    attribute :metadata?, Types::Hash.optional
    attribute :source_url?, Types::String.optional
    attribute :created_at?, Types::JSON::DateTime.optional

    # Override db_init to use RAG schema
    def self.db_init
      rag_db_init(vector_dimension: 1536, full_text_fields: ['content', 'metadata'])
    end
  end
end

if $0 == __FILE__
  # Connect to database
  Arcade::Init.connect('test')

  # Create the type with RAG schema
  RAG::Document.create_type

  # Example: Insert a document with embedding
  # In practice, you would generate the embedding using an external service
  sample_embedding = Array.new(1536) { rand }  # Replace with actual embedding
  
  doc = RAG::Document.create(
    content: "ArcadeDB is a multi-model graph database built from the ground up.",
    embedding: sample_embedding,
    metadata: { author: "ArcadeDB Team", tags: ["database", "graph"] },
    source_url: "https://arcadedb.com",
    created_at: DateTime.now
  )

  puts "Created document: #{doc.rid}"

  # Example: Vector similarity search
  # query_embedding = generate_embedding("What is a graph database?")
  # results = RAG::Document.vector_search(query_embedding, limit: 5, threshold: 0.7)
  # puts "Found #{results.count} similar documents"

  # Example: Hybrid search (vector + full-text)
  # results = RAG::Document.hybrid_search(
  #   query_embedding, 
  #   "multi-model graph database", 
  #   limit: 5
  # )
  # puts "Found #{results.count} hybrid search results"

  puts "RAG schema setup complete!"
end
