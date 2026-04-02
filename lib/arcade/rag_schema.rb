module Arcade
  ##
  # Ragschema - A generic class to implement a RAG (Retrieval-Augmented Generation)
  # compatible database schema for ArcadeDB.
  #
  # This module provides a default-index configuration optimized for:
  # - Vector similarity search (semantic embeddings)
  # - Metadata filtering
  #
  # Usage:
  #   class MyDocument < Arcade::Vertex
  #     include Arcade::Ragschema
  #     attribute :content, Types::String
  #     attribute :metadata, Types::Hash.optional
  #   end
  #
  #   MyDocument.create_type
  #
  module Ragschema
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      ##
      # Returns the default RAG schema setup commands
      # to be executed after type creation
      #
      # @param vector_dimension [Integer] Dimension of vector embeddings (default: 1536 for OpenAI)
      # @return [String] SQL commands for index creation
      def rag_schema(vector_dimension: 1536)
        type_name = database_name
        commands = []

        # Vector index for semantic similarity search
        commands << "CREATE INDEX ON #{type_name} (embedding) LSM_VECTOR METADATA {dimensions: #{vector_dimension}, similarity: 'COSINE'}"

        # Metadata index for filtering
        commands << "CREATE INDEX IF NOT EXISTS ON #{type_name} (metadata) NOTUNIQUE"

        commands.join("\n")
      end

      ##
      # Default db_init method for RAG-compatible models
      # Override this in your model class to customize
      #
      # @return [String] SQL commands to be executed on database
      def rag_db_init(vector_dimension: 1536)
        <<~SQL
          CREATE PROPERTY #{database_name}.embedding ARRAY_OF_FLOATS
          CREATE PROPERTY #{database_name}.content STRING
          CREATE PROPERTY #{database_name}.metadata MAP
          CREATE PROPERTY #{database_name}.source_url STRING
          CREATE PROPERTY #{database_name}.created_at DATETIME
          #{rag_schema(vector_dimension: vector_dimension)}
        SQL
      end

      ##
      # Perform vector similarity search across all documents
      # Returns metadata only (not embedding vectors) for efficiency
      #
      # @param query_embedding [Array<Float>] The embedding vector to search for
      # @param limit [Integer] Maximum number of results (default: 10)
      # @param threshold [Float] Minimum similarity score (default: 0.7)
      # @return [Array<Hash>] Matching records with metadata and similarity score
      def vector_search(query_embedding, limit: 10, threshold: 0.7)
        raise "vector_search must be called on a model class" unless respond_to?(:database_name)

        type_name = database_name
        # Convert array to ArcadeDB array literal format: [1.0,2.0,3.0]
        embedding_array = "[#{query_embedding.join(',')}]"

        # Select metadata fields only (not embedding) for efficiency
        # Include @rid for reference and all other fields except embedding
        query = <<~SQL
          SELECT @rid, title, content, category, tags, author, source_url, created_at, updated_at, distance AS similarity
          FROM (
            SELECT expand(vectorNeighbors('#{type_name}[embedding]', #{embedding_array}, #{limit}))
          )
          WHERE distance <= (1.0 - #{threshold})
          ORDER BY distance ASC
        SQL

        db.query(query)
      end

      ##
      # Perform hybrid search combining vector similarity with SQL LIKE filtering
      # Returns metadata only (not embedding vectors) for efficiency
      #
      # @param query_embedding [Array<Float>] The embedding vector
      # @param text_query [String] SQL LIKE search query
      # @param limit [Integer] Maximum number of results (default: 10)
      # @param vector_threshold [Float] Minimum vector similarity (default: 0.7)
      # @return [Array<Hash>] Matching records with metadata and similarity score
      def hybrid_search(query_embedding, text_query, limit: 10, vector_threshold: 0.7)
        raise "hybrid_search must be called on a model class" unless respond_to?(:database_name)

        type_name = database_name
        # Convert array to ArcadeDB array literal format: [1.0,2.0,3.0]
        embedding_array = "[#{query_embedding.join(',')}]"

        # Select metadata fields only (not embedding) for efficiency
        query = <<~SQL
          SELECT @rid, title, content, category, tags, author, source_url, created_at, updated_at, distance AS similarity
          FROM (
            SELECT expand(vectorNeighbors('#{type_name}[embedding]', #{embedding_array}, #{limit}))
          )
          WHERE distance <= (1.0 - #{vector_threshold})
            AND content LIKE '%#{text_query}%'
          ORDER BY distance ASC
        SQL

        db.query(query)
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
  end
end
