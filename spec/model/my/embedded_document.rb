module My
	class EmbeddedDocument  < Arcade::Document
		attribute :a_list? , Types::Nominal::Any
		attribute :a_label?,  Types::String
		attribute :a_map?,  Types::Nominal::Any
		attribute :a_emb?,  Types::Nominal::Any

   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
__END__
CREATE PROPERTY my_embedded_document.a_label STRING
CREATE PROPERTY my_embedded_document.a_emb   EMBEDDED
CREATE INDEX `Embedded[label]` ON my_embedded_document ( a_label ) UNIQUE
CREATE PROPERTY my_embedded_document.a_list LIST
CREATE PROPERTY my_embedded_document.a_set MAP


