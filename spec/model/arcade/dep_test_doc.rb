module Arcade
  class DepTestDoc < TestDocument
    # inherents
  #  attribute :name?, Types::String
  #  attribute :age?, Types::Integer
  #  attribute :c?, Types::Integer
  #  attribute :d?, Types::Hash

   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/n, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
__END__
