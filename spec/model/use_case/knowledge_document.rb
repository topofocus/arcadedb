module UseCase
  class KnowledgeDocument < Arcade::Vertex
    include Arcade::Ragschema

    attribute :title, Types::String
    attribute :content, Types::String
    attribute :embedding?, Types::Nominal::Array.optional
    attribute :category, Types::String.optional
    attribute :tags, Types::Array.of(Types::String).optional
    attribute :author, Types::String.optional
    attribute :source_url, Types::String.optional
    attribute :created_at, Types::DateTime.optional
    attribute :updated_at, Types::DateTime.optional

    def self.db_init
      rag_db_init(vector_dimension: 1536)
    end
  end
end

__END__
CREATE PROPERTY use_case_knowledge_document.embedding ARRAY_OF_FLOATS
CREATE PROPERTY use_case_knowledge_document.content STRING
CREATE PROPERTY use_case_knowledge_document.metadata MAP
CREATE PROPERTY use_case_knowledge_document.source_url STRING
CREATE PROPERTY use_case_knowledge_document.created_at DATETIME
CREATE INDEX ON use_case_knowledge_document (embedding) LSM_VECTOR METADATA {dimensions: 1536, similarity: 'COSINE'}
CREATE INDEX IF NOT EXISTS ON use_case_knowledge_document (metadata) NOTUNIQUE
