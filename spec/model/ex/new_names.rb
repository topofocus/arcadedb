module  Ex
  class  NewNames < Arcade::Document
    attribute :name?, Types::String
    attribute :age?, Types::Integer
    attribute :children?, Types::Nominal::Any



   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
__END__
CREATE PROPERTY ex_new_names.name STRING
CREATE INDEX `Example[newnames]` ON ex_new_names ( name ) UNIQUE
