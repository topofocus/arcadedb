module Arcade
  ##
  # RAGSchema - A generic class to implement a RAG (Retrieval-Augmented Generation)
  # compatible database schema for ArcadeDB.
  #
  # This module provides a default-index configuration optimized for:
  # - Vector similarity search (semantic embeddings)
  # - Full-text search (keyword matching)
  # - Metadata filtering
  #
  # Usage:
  #   class MyDocument < Arcade::Vertex
  #     include Arcade::RAGSchema
  #     attribute :content, Types::String
  #     attribute :metadata, Types::Hash.optional
  #   end
  #
  #   MyDocument.create_type
  #
  module RAGSchema
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      ##
      # Returns the default RAG schema setup commands
      # to be executed after type creation
      #
      # @param vector_dimension [Integer] Dimension of vector embeddings (default: 1536 for OpenAI)
      # @param full_text_fields [Array<String>] Fields to index for full-text search
      # @return [String] SQL commands for index creation
      def rag_schema(vector_dimension: 1536, full_text_fields: ['content'])
        type_name = database_name
        commands = []

        # Vector index for semantic similarity search
        commands << "CREATE INDEX IF NOT EXISTS ON #{type_name} (embedding) FULLVECTOR"

        # Full-text indexes for keyword search
        full_text_fields.each do |field|
          commands << "CREATE INDEX IF NOT EXISTS ON #{type_name} (#{field}) FULLTEXT"
        end

        # Metadata index for filtering
        commands << "CREATE INDEX IF NOT EXISTS ON #{type_name} (metadata) NOTUNIQUE"

        commands.join("\n")
      end

      ##
      # Default db_init method for RAG-compatible models
      # Override this in your model class to customize
      #
      # @return [String] SQL commands to be executed on database
      def rag_db_init(vector_dimension: 1536, full_text_fields: ['content'])
        <<~SQL
          CREATE PROPERTY #{database_name}.embedding EMBEDDED
          CREATE PROPERTY #{database_name}.content TEXT
          CREATE PROPERTY #{database_name}.metadata EMBEDDED
          CREATE PROPERTY #{database_name}.source_url STRING
          CREATE PROPERTY #{database_name}.created_at DATETIME
          #{rag_schema(vector_dimension: vector_dimension, full_text_fields: full_text_fields)}
        SQL
      end
    end

    ##
    # Instance method to perform vector similarity search
    #
    # @param query_embedding [Array<Float>] The embedding vector to search for
    # @param limit [Integer] Maximum number of results (default: 10)
    # @param threshold [Float] Minimum similarity score (default: 0.7)
    # @return [Array<Base>] Matching records
    def vector_search(query_embedding, limit: 10, threshold: 0.7)
      self.class.vector_search(query_embedding, limit: limit, threshold: threshold)
    end

    class << self
      ##
      # Perform vector similarity search across all documents
      #
      # @param query_embedding [Array<Float>] The embedding vector to search for
      # @param limit [Integer] Maximum number of results (default: 10)
      # @param threshold [Float] Minimum similarity score (default: 0.7)
      # @return [Array<Base>] Matching records
      def vector_search(query_embedding, limit: 10, threshold: 0.7)
        raise "vector_search must be called on a model class" unless respond_to?(:database_name)
        
        type_name = database_name
        embedding_json = query_embedding.to_json
        
        query = <<~SQL
          SELECT *, 
                 vectorSimilarities(embedding, #{embedding_json}) AS similarity
          FROM #{type_name}
          WHERE vectorSimilarities(embedding, #{embedding_json}) >= #{threshold}
          ORDER BY similarity DESC
          LIMIT #{limit}
        SQL
        
        db.query(query).select_result
      end

      ##
      # Perform hybrid search combining vector and full-text search
      #
      # @param query_embedding [Array<Float>] The embedding vector
      # @param text_query [String] Full-text search query
      # @param limit [Integer] Maximum number of results (default: 10)
      # @param vector_threshold [Float] Minimum vector similarity (default: 0.7)
      # @return [Array<Base>] Matching records
      def hybrid_search(query_embedding, text_query, limit: 10, vector_threshold: 0.7)
        raise "hybrid_search must be called on a model class" unless respond_to?(:database_name)
        
        type_name = database_name
        embedding_json = query_embedding.to_json
        
        query = <<~SQL
          SELECT *, 
                 vectorSimilarities(embedding, #{embedding_json}) AS similarity
          FROM #{type_name}
          WHERE vectorSimilarities(embedding, #{embedding_json}) >= #{vector_threshold}
            AND content MATCH '#{text_query}'
          ORDER BY similarity DESC
          LIMIT #{limit}
        SQL
        
        db.query(query).select_result
      end
    end
  end
end
