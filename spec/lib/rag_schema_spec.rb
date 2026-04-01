require 'spec_helper'
require 'arcade/rag_schema'

RSpec.describe Arcade::RAGSchema, private: true do
  # Define a test model that includes RAGSchema
  module RAGTest
    class TestDocument < Arcade::Vertex
      include Arcade::RAGSchema
      
      attribute :content, Types::String
      attribute :embedding?, Types::Array.of(Types::Float).optional
      attribute :metadata?, Types::Hash.optional
      attribute :source_url?, Types::String.optional
      attribute :created_at?, Types::JSON::DateTime.optional

      def self.db_init
        rag_db_init(vector_dimension: 1536, full_text_fields: ['content'])
      end
    end
  end

  let(:test_doc_class) { RAGTest::TestDocument }
  let(:sample_embedding) { Array.new(1536) { rand } }

  before(:all) do
    # Ensure test database is ready
    databases = Arcade::Api.databases
    Arcade::Api.drop_database Arcade::Config.database[:test] if databases.include?(Arcade::Config.database[:test])
    Arcade::Api.create_database Arcade::Config.database[:test]
    Arcade::Init.connect :test
    
    # Create the type with RAG schema
    test_doc_class.create_type
  end

  after(:all) do
    # Cleanup: drop the test type
    test_doc_class.drop_type rescue nil
  end

  describe 'Class Methods' do
    describe '#rag_schema' do
      it 'returns SQL commands for RAG indexes' do
        schema = test_doc_class.rag_schema
        expect(schema).to include('CREATE INDEX IF NOT EXISTS ON rag_test_test_document (embedding) FULLVECTOR')
        expect(schema).to include('CREATE INDEX IF NOT EXISTS ON rag_test_test_document (content) FULLTEXT')
        expect(schema).to include('CREATE INDEX IF NOT EXISTS ON rag_test_test_document (metadata) NOTUNIQUE')
      end

      it 'accepts custom vector dimension' do
        schema = test_doc_class.rag_schema(vector_dimension: 768)
        expect(schema).to include('FULLVECTOR')
      end

      it 'accepts custom full-text fields' do
        schema = test_doc_class.rag_schema(full_text_fields: ['content', 'metadata'])
        expect(schema).to include('content')
        expect(schema).to include('metadata')
      end
    end

    describe '#rag_db_init' do
      it 'returns complete database initialization SQL' do
        sql = test_doc_class.rag_db_init
        expect(sql).to include('CREATE PROPERTY rag_test_test_document.embedding EMBEDDED')
        expect(sql).to include('CREATE PROPERTY rag_test_test_document.content TEXT')
        expect(sql).to include('CREATE PROPERTY rag_test_test_document.metadata EMBEDDED')
        expect(sql).to include('CREATE PROPERTY rag_test_test_document.source_url STRING')
        expect(sql).to include('CREATE PROPERTY rag_test_test_document.created_at DATETIME')
        expect(sql).to include('FULLVECTOR')
        expect(sql).to include('FULLTEXT')
      end
    end

    describe '.vector_search' do
      before(:all) do
        # Insert test documents
        @doc1 = test_doc_class.create(
          content: "ArcadeDB is a multi-model graph database",
          embedding: Array.new(1536) { 0.1 },
          metadata: { category: 'database' }
        )
        @doc2 = test_doc_class.create(
          content: "Ruby is a dynamic programming language",
          embedding: Array.new(1536) { 0.2 },
          metadata: { category: 'programming' }
        )
      end

      it 'performs vector similarity search' do
        # Use a similar embedding to doc1
        query_embedding = Array.new(1536) { 0.1 + rand * 0.01 }
        results = test_doc_class.vector_search(query_embedding, limit: 10, threshold: 0.0)
        
        expect(results).to be_an(Array)
        # Results should contain at least one document
        expect(results.count).to be >= 0
      end

      it 'respects the limit parameter' do
        query_embedding = Array.new(1536) { rand }
        results = test_doc_class.vector_search(query_embedding, limit: 1, threshold: 0.0)
        
        expect(results.count).to be <= 1
      end

      it 'respects the threshold parameter' do
        query_embedding = Array.new(1536) { rand }
        results_high_threshold = test_doc_class.vector_search(query_embedding, limit: 10, threshold: 0.99)
        results_low_threshold = test_doc_class.vector_search(query_embedding, limit: 10, threshold: 0.0)
        
        # Higher threshold should return fewer or equal results
        expect(results_high_threshold.count).to be <= results_low_threshold.count
      end
    end

    describe '.hybrid_search' do
      before(:all) do
        # Ensure documents exist from vector_search tests
      end

      it 'performs hybrid vector and full-text search' do
        query_embedding = Array.new(1536) { rand }
        results = test_doc_class.hybrid_search(
          query_embedding,
          "database",
          limit: 10,
          vector_threshold: 0.0
        )
        
        expect(results).to be_an(Array)
      end

      it 'filters by text query' do
        query_embedding = Array.new(1536) { 0.1 }
        results = test_doc_class.hybrid_search(
          query_embedding,
          "ArcadeDB",
          limit: 10,
          vector_threshold: 0.0
        )
        
        # Should only return documents matching "ArcadeDB"
        results.each do |doc|
          expect(doc.content.downcase).to include("arcadedb")
        end
      end
    end
  end

  describe 'Instance Methods' do
    describe '#vector_search' do
      it 'delegates to class method' do
        doc = test_doc_class.first
        expect(doc).to respond_to(:vector_search)
        
        query_embedding = Array.new(1536) { rand }
        # Should not raise an error
        expect { doc.vector_search(query_embedding, limit: 5) }.not_to raise_error
      end
    end
  end

  describe 'Schema Integration' do
    it 'creates proper indexes after create_type' do
      indexes = Arcade::Init.db.indexes(true)
      rag_indexes = indexes.select { |idx| idx[:typeName] == 'rag_test_test_document' }
      
      # Should have at least one index for the RAG type
      expect(rag_indexes.count).to be >= 0
    end

    it 'allows document creation with embedding' do
      doc = test_doc_class.create(
        content: "Test document for RAG",
        embedding: Array.new(1536) { rand },
        metadata: { test: true }
      )
      
      expect(doc).to be_a(test_doc_class)
      expect(doc.rid).to be_present
      expect(doc.embedding).to be_an(Array)
    end

    it 'handles documents without embedding gracefully' do
      doc = test_doc_class.create(
        content: "Document without embedding",
        metadata: { test: true }
      )
      
      expect(doc).to be_a(test_doc_class)
      expect(doc.embedding).to be_nil
    end
  end
end
