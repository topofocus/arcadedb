module Arcade
  class TestDocument < Document
    attribute :name?, Types::String
    attribute :age?, Types::Integer
    attribute :c?, Types::Integer
    attribute :d?, Types::Hash

   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
__END__
CREATE PROPERTY test_document.name STRING
CREATE PROPERTY test_document.age INTEGER
CREATE INDEX `TestDocument[name]` ON test_document (name, age) UNIQUE
