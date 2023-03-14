module Arcade
  # note:  DateDocument is not allowed, as it resolves t Date::Document as ruby-class
  class DatDocument < Document
    attribute :date, Types::JSON::Date
    attribute :name?, Types::Nominal::String
    attribute :age?, Types::Nominal::Integer
    attribute :c?, Types::Nominal::Integer

   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
##
__END__
CREATE PROPERTY dat_document.date DATE
CREATE PROPERTY dat_document.name STRING
CREATE PROPERTY dat_document.age INTEGER
CREATE INDEX  ON dat_document (date) UNIQUE
