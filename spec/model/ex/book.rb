module  Ex
  class  Book < Arcade::Vertex
    attribute :title, Types::String

   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
##
__END__
CREATE PROPERTY ex_book.title STRING
CREATE PROPERTY ex_bool.married BOOLEAN
CREATE INDEX `Example[book]` ON ex_book ( title ) UNIQUE
