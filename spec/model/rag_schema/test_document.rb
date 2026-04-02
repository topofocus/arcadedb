module Ragschema
  class TestDocument < Arcade::Vertex
    include Arcade::Ragschema

    attribute :content, Types::String
    attribute :embedding?, Types::Nominal::Array.optional
    attribute :metadata?, Types::Hash.optional
    attribute :source_url?, Types::String.optional
    attribute :created_at?, Types::JSON::DateTime.optional

    def self.db_init
      rag_db_init(vector_dimension: 1536)
    end
  end
end

__END__
CREATE PROPERTY ragschema_test_document.embedding ARRAY_OF_FLOATS
CREATE PROPERTY ragschema_test_document.content STRING
CREATE PROPERTY ragschema_test_document.metadata MAP
CREATE PROPERTY ragschema_test_document.source_url STRING
CREATE PROPERTY ragschema_test_document.created_at DATETIME
CREATE INDEX ON ragschema_test_document (embedding) LSM_VECTOR METADATA {dimensions: 1536, similarity: 'COSINE'}
CREATE INDEX IF NOT EXISTS ON ragschema_test_document (metadata) NOTUNIQUE
