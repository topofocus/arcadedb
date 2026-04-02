# RAG Use Case Demo - Knowledge Base Search
#
# This example demonstrates a complete RAG (Retrieval-Augmented Generation) workflow
# using a knowledge base of technical documentation.
#
# Features demonstrated:
# - Document ingestion with vector embeddings
# - Vector similarity search for semantic queries
# - Hybrid search combining vector + full-text
# - Category and tag-based filtering
# - Real-world query scenarios
#
# Run with: ruby examples/rag_usecase_demo.rb

require 'bundler/setup'
require 'arcade'

# =============================================================================
# Model Definition
# =============================================================================

module UseCase
  class KnowledgeDocument < Arcade::Vertex
    include Arcade::Ragschema

    attribute :title, Types::String
    attribute :content, Types::String
    attribute :embedding?, Types::Array.of(Types::Float).optional
    attribute :category, Types::String.optional
    attribute :tags, Types::Array.of(Types::String).optional
    attribute :author, Types::String.optional
    attribute :source_url, Types::String.optional
    attribute :created_at, Types::DateTime.optional
    attribute :updated_at, Types::DateTime.optional

    def self.db_init
      rag_db_init(
        vector_dimension: 1536,
        full_text_fields: ['title', 'content', 'category']
      )
    end
  end

  # =============================================================================
  # Helper for generating mock embeddings (for demo purposes)
  # In production, use a real embedding service (OpenAI, HuggingFace, etc.)
  # =============================================================================

  module EmbeddingHelper
    ##
    # Generate a deterministic mock embedding for demonstration
    #
    # @param text [String] Text to embed
    # @param seed [Integer] Seed for deterministic generation
    # @return [Array<Float>] 1536-dimensional vector
    def self.generate_mock_embedding(text, seed: 42)
      base_hash = (text + seed.to_s).hash
      vector = []
      1536.times do |i|
        value = ((base_hash * (i + 1) * 31) % 10000) / 10000.0 - 0.5
        vector << value
      end
      vector
    end
  end
end

# =============================================================================
# Demo Data - Technical Knowledge Base
# =============================================================================

KNOWLEDGE_BASE = [
  {
    title: 'Introduction to Graph Databases',
    content: 'Graph databases are designed to store and treat relationships between data entities as first-class citizens. Unlike relational databases, graph databases use nodes and edges to represent and store data. This makes them ideal for analyzing complex relationships and patterns in data.',
    category: 'Database Fundamentals',
    tags: ['graph', 'database', 'nosql', 'fundamentals'],
    author: 'Database Team'
  },
  {
    title: 'ArcadeDB Overview',
    content: 'ArcadeDB is a multi-model graph database built from the ground up with support for vertices, edges, documents, arrays, and vectors. It provides a SQL-like query language and supports RAG (Retrieval-Augmented Generation) workloads with native vector search capabilities.',
    category: 'Database Systems',
    tags: ['arcadedb', 'graph', 'vector', 'rag'],
    author: 'ArcadeDB Team'
  },
  {
    title: 'Vector Search Fundamentals',
    content: 'Vector search, also known as semantic search, uses mathematical representations of data called embeddings. These embeddings capture the semantic meaning of text, allowing for similarity-based searches that understand context rather than just keyword matching.',
    category: 'Search Technology',
    tags: ['vector', 'embedding', 'similarity', 'ai'],
    author: 'AI Research Team'
  },
  {
    title: 'RAG Architecture Patterns',
    content: 'Retrieval-Augmented Generation (RAG) combines retrieval-based and generation-based approaches. It first retrieves relevant documents from a knowledge base using vector similarity, then uses a language model to generate responses based on the retrieved context.',
    category: 'AI Architecture',
    tags: ['rag', 'llm', 'retrieval', 'generation'],
    author: 'ML Engineering'
  },
  {
    title: 'SQL Query Optimization',
    content: 'Query optimization in SQL databases involves techniques like indexing, query planning, and execution strategy selection. Proper indexing strategies can dramatically improve query performance, especially for complex joins and aggregations.',
    category: 'Database Performance',
    tags: ['sql', 'optimization', 'indexing', 'performance'],
    author: 'Performance Team'
  },
  {
    title: 'NoSQL vs SQL Databases',
    content: 'NoSQL databases offer flexible schemas and horizontal scaling, making them suitable for unstructured data and high-velocity applications. SQL databases provide ACID transactions and structured querying capabilities. The choice depends on your specific use case requirements.',
    category: 'Database Comparison',
    tags: ['nosql', 'sql', 'comparison', 'architecture'],
    author: 'Architecture Team'
  },
  {
    title: 'Full-Text Search Implementation',
    content: 'Full-text search indexes allow for efficient text querying beyond simple LIKE matches. They support tokenization, stemming, and relevance scoring. Modern search engines combine full-text search with vector embeddings for hybrid search capabilities.',
    category: 'Search Technology',
    tags: ['fulltext', 'search', 'indexing', 'hybrid'],
    author: 'Search Team'
  },
  {
    title: 'Embedding Models for Text',
    content: 'Text embedding models like BERT, Sentence Transformers, and OpenAI embeddings convert text into dense vectors. These vectors capture semantic relationships, enabling tasks like semantic search, clustering, and similarity detection.',
    category: 'Machine Learning',
    tags: ['embedding', 'bert', 'nlp', 'transformers'],
    author: 'NLP Team'
  }
].freeze

# =============================================================================
# Demo Functions
# =============================================================================

def print_header(title)
  puts "\n" + '=' * 70
  puts title.center(70)
  puts '=' * 70
end

def print_section(title)
  puts "\n--- #{title} ---\n"
end

def print_document(doc, show_similarity: false)
  puts "  Title: #{doc.title}"
  puts "  Category: #{doc.category}"
  puts "  Author: #{doc.author}"
  puts "  Tags: #{doc.tags.join(', ')}"
  puts "  Content: #{doc.content[0..150]}..."
  puts "  Similarity: #{doc.similarity.round(4)}" if doc.respond_to?(:similarity) && doc.similarity
  puts
end

def load_knowledge_base
  print_section('Loading Knowledge Base')

  KNOWLEDGE_BASE.each do |doc_data|
    embedding = UseCase::EmbeddingHelper.generate_mock_embedding(
      doc_data[:title] + ' ' + doc_data[:content]
    )

    UseCase::KnowledgeDocument.create(
      title: doc_data[:title],
      content: doc_data[:content],
      embedding: embedding,
      category: doc_data[:category],
      tags: doc_data[:tags],
      author: doc_data[:author],
      created_at: DateTime.now
    )

    puts "  ✓ Loaded: #{doc_data[:title]}"
  end

  total = UseCase::KnowledgeDocument.count
  puts "\nTotal documents: #{total}"
end

def demo_vector_search
  print_section('Vector Similarity Search')

  queries = [
    'What is a graph database and how does it work?',
    'How does RAG architecture work?',
    'Explain vector embeddings for text search'
  ]

  queries.each do |query|
    puts "\nQuery: \"#{query}\""
    puts "-" * 50

    query_embedding = UseCase::EmbeddingHelper.generate_mock_embedding(query)

    results = UseCase::KnowledgeDocument.vector_search(
      query_embedding,
      limit: 3,
      threshold: 0.0
    )

    results.each_with_index do |doc, i|
      puts "  [#{i + 1}] #{doc.title} (similarity: #{doc.similarity.round(4) if doc.similarity})"
    end
  end
end

def demo_hybrid_search
  print_section('Hybrid Search (Vector + Full-Text)')

  searches = [
    { query: 'database performance', text: 'optimization' },
    { query: 'search technology', text: 'Full-Text' },
    { query: 'machine learning', text: 'embedding' }
  ]

  searches.each do |search|
    puts "\nVector Query: \"#{search[:query]}\""
    puts "Text Filter: \"#{search[:text]}\""
    puts "-" * 50

    query_embedding = UseCase::EmbeddingHelper.generate_mock_embedding(search[:query])

    results = UseCase::KnowledgeDocument.hybrid_search(
      query_embedding,
      search[:text],
      limit: 5,
      vector_threshold: 0.0
    )

    if results.empty?
      puts "  No results found"
    else
      results.each_with_index do |doc, i|
        puts "  [#{i + 1}] #{doc.title}"
      end
    end
  end
end

def demo_category_filtering
  print_section('Category-Based Filtering')

  categories = ['Search Technology', 'Database Systems', 'Machine Learning']

  categories.each do |category|
    puts "\nCategory: #{category}"
    puts "-" * 50

    results = UseCase::KnowledgeDocument.where("category = '#{category}'")

    results.each do |doc|
      puts "  • #{doc.title} (#{doc.author})"
    end
  end
end

def demo_tag_search
  print_section('Tag-Based Search')

  tags = ['vector', 'graph', 'embedding']

  tags.each do |tag|
    puts "\nTag: #{tag}"
    puts "-" * 50

    results = UseCase::KnowledgeDocument.where("tags CONTAINS '#{tag}'")

    results.each do |doc|
      puts "  • #{doc.title} [#{doc.tags.join(', ')}]"
    end
  end
end

def demo_real_world_queries
  print_section('Real-World Query Scenarios')

  scenarios = {
    'What is ArcadeDB?' => 'Definition query',
    'difference between SQL and NoSQL' => 'Comparison query',
    'How to optimize database queries?' => 'How-to query',
    'Explain RAG benefits' => 'Concept exploration'
  }

  scenarios.each do |query, type|
    puts "\n[#{type}] \"#{query}\""
    puts "-" * 50

    query_embedding = UseCase::EmbeddingHelper.generate_mock_embedding(query)

    results = UseCase::KnowledgeDocument.vector_search(
      query_embedding,
      limit: 2,
      threshold: 0.0
    )

    results.each do |doc|
      puts "  → #{doc.title}"
    end
  end
end

# =============================================================================
# Main Demo Runner
# =============================================================================

def run_demo
  print_header('RAG Use Case Demo - Knowledge Base Search')

  # Connect to database
  Arcade::Init.connect('test')

  # Create type if needed
  unless Arcade::Init.db.types.include?('UseCase_KnowledgeDocument')
    puts 'Creating KnowledgeDocument type...'
    UseCase::KnowledgeDocument.create_type
  end

  # Clear existing data for fresh demo
  UseCase::KnowledgeDocument.delete_all rescue nil

  # Run demos
  load_knowledge_base
  demo_vector_search
  demo_hybrid_search
  demo_category_filtering
  demo_tag_search
  demo_real_world_queries

  print_header('Demo Complete!')
  puts "\nThis demo showcased:"
  puts "  ✓ Document ingestion with vector embeddings"
  puts "  ✓ Vector similarity search for semantic queries"
  puts "  ✓ Hybrid search (vector + full-text)"
  puts "  ✓ Category and tag-based filtering"
  puts "  ✓ Real-world query scenarios"
  puts "\nFor more information, see:"
  puts "  - RAG_SCHEMA.md"
  puts "  - spec/lib/usecase/rag_integration_spec.rb"
  puts
end

# Run if executed directly
if $0 == __FILE__
  run_demo
end
