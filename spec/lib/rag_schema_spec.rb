require 'spec_helper'
require 'arcade/rag_schema'
require_relative '../model/rag_schema/test_document'

RSpec.describe Arcade::Ragschema, private: true do
  let(:sample_embedding) { Array.new(1536) { rand } }

  before(:all) do
    # Set logger level to WARN to reduce output

    # Ensure test database is ready
    databases = Arcade::Api.databases
    Arcade::Api.drop_database Arcade::Config.database[:test] if databases.include?(Arcade::Config.database[:test])
    Arcade::Api.create_database Arcade::Config.database[:test]
    Arcade::Init.connect :test

    # Create the type with RAG schema
    Arcade::Database.logger.level = Logger::WARN
    Ragschema::TestDocument.create_type
  end

  after(:all) do
    # Cleanup: drop the test type
    Ragschema::TestDocument.drop_type rescue nil
  end

  describe 'Class Methods' do
    describe '#rag_schema' do
      it 'returns SQL commands for RAG indexes' do
        schema = Ragschema::TestDocument.rag_schema
        expect(schema).to include("CREATE INDEX ON ragschema_test_document (embedding) LSM_VECTOR METADATA {dimensions: 1536, similarity: 'COSINE'}")
        expect(schema).to include('CREATE INDEX IF NOT EXISTS ON ragschema_test_document (metadata) NOTUNIQUE')
      end

      it 'accepts custom vector dimension' do
        schema = Ragschema::TestDocument.rag_schema(vector_dimension: 768)
        expect(schema).to include("LSM_VECTOR METADATA {dimensions: 768, similarity: 'COSINE'}")
      end
    end

    describe '#rag_db_init' do
      it 'returns complete database initialization SQL' do
        sql = Ragschema::TestDocument.rag_db_init
        expect(sql).to include('CREATE PROPERTY ragschema_test_document.embedding ARRAY_OF_FLOATS')
        expect(sql).to include('CREATE PROPERTY ragschema_test_document.content STRING')
        expect(sql).to include('CREATE PROPERTY ragschema_test_document.metadata MAP')
        expect(sql).to include('CREATE PROPERTY ragschema_test_document.source_url STRING')
        expect(sql).to include('CREATE PROPERTY ragschema_test_document.created_at DATETIME')
        expect(sql).to include("LSM_VECTOR METADATA {dimensions: 1536, similarity: 'COSINE'}")
      end
    end

    describe '.vector_search' do
      before(:all) do
        # Insert test documents
        @doc1 = Ragschema::TestDocument.create(
          content: "ArcadeDB is a multi-model graph database",
          embedding: Array.new(1536) { 0.1 },
          metadata: { category: 'database' }
        )
        @doc2 = Ragschema::TestDocument.create(
          content: "Ruby is a dynamic programming language",
          embedding: Array.new(1536) { 0.2 },
          metadata: { category: 'programming' }
        )
      end

      it 'performs vector similarity search' do
        # Use a similar embedding to doc1
        query_embedding = Array.new(1536) { 0.1 + rand * 0.01 }
        results = Ragschema::TestDocument.vector_search(query_embedding, limit: 10, threshold: 0.0)

        # Returns array of hashes with metadata
        expect(results).to be_an(Array)
      end

      it 'respects the limit parameter' do
        query_embedding = Array.new(1536) { rand }
        results = Ragschema::TestDocument.vector_search(query_embedding, limit: 1, threshold: 0.0)

        expect(results).to be_an(Array)
        expect(results.count).to be <= 1
      end

      it 'respects the threshold parameter' do
        query_embedding = Array.new(1536) { rand }
        results_high_threshold = Ragschema::TestDocument.vector_search(query_embedding, limit: 10, threshold: 0.99)
        results_low_threshold = Ragschema::TestDocument.vector_search(query_embedding, limit: 10, threshold: 0.0)

        # Higher threshold should return fewer or equal results
        expect(results_high_threshold).to be_an(Array)
        expect(results_low_threshold).to be_an(Array)
        expect(results_high_threshold.count).to be <= results_low_threshold.count
      end
    end

    describe '.hybrid_search' do
      before(:all) do
        # Ensure documents exist from vector_search tests
      end

      it 'performs hybrid vector and SQL LIKE search' do
        query_embedding = Array.new(1536) { rand }
        results = Ragschema::TestDocument.hybrid_search(
          query_embedding,
          "database",
          limit: 10,
          vector_threshold: 0.0
        )

        expect(results).to be_an(Array)
      end

      it 'filters by text query using LIKE' do
        query_embedding = Array.new(1536) { 0.1 }
        results = Ragschema::TestDocument.hybrid_search(
          query_embedding,
          "ArcadeDB",
          limit: 10,
          vector_threshold: 0.0
        )

        # Should only return documents matching "ArcadeDB" in content
        results.each do |doc|
          expect(doc[:content].to_s.downcase).to include("arcadedb")
        end
      end
    end
  end

  describe 'Instance Methods' do
    describe '#vector_search' do
      it 'delegates to class method' do
        doc = Ragschema::TestDocument.first
        expect(doc).to respond_to(:vector_search)

        query_embedding = Array.new(1536) { rand }
        # Should not raise an error - returns array of hashes
        expect { doc.vector_search(query_embedding, limit: 5) }.not_to raise_error
      end
    end
  end

  describe 'Schema Integration'  do
    it 'creates proper indexes after create_type' do
      indexes = Arcade::Init.db.indexes(true)
      rag_indexes = indexes.select { |idx| idx[:typeName] == 'ragschema_test_document' }

      # Should have at least the vector index
      expect(rag_indexes.count).to be >= 1
    end

    it 'allows document creation with embedding' do
      result = Ragschema::TestDocument.create(
        content: "Test document for RAG",
        embedding: Array.new(1536) { rand },
        metadata: { test: true }
      )
      # insert returns the rid string, load the document manually
      doc = result.is_a?(String) ? result.load_rid : result

      expect(doc).to be_a(Ragschema::TestDocument)
      expect(doc.rid).to be_present
      expect(doc.embedding).to be_an(Array)
    end

    it 'handles documents without embedding gracefully' do
      result = Ragschema::TestDocument.insert(
        content: "Document without embedding",
        metadata: { test: true }
      )
      # insert returns the rid string, load the document manually
      doc = result.is_a?(String) ? result.load_rid : result

      expect(doc).to be_a(Ragschema::TestDocument)
      expect(doc.embedding).to be_nil
    end
  end
end
