module  Ex
  class  Names < Arcade::Document
    attribute :name?, Types::String
    attribute :age?, Types::Integer
    attribute :bez?, Types::Nominal::Any
    attribute :child?, Types::Nominal::Array

  def parent
    query( where: {child: rid})
  end


   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
__END__
CREATE PROPERTY ex_names.child LINK
CREATE PROPERTY ex_names.name STRING
CREATE INDEX `Example[names]` ON ex_names ( name ) UNIQUE
