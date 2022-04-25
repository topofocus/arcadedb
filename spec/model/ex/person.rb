module  Ex
  class  Person < Arcade::Document
    attribute :name?, Types::String
    attribute :father?, Types::Nominal::Array
    attribute :children?, Types::Nominal::Array



   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
__END__
CREATE PROPERTY ex_person.childen SET
CREATE PROPERTY ex_person.name LINK
CREATE INDEX `Example[person]` ON ex_peron ( name ) UNIQUE
