
module My
  class  Emb < Arcade::Document
    attribute :a_string?, Types::String
   attribute :b_int?, Types::Nominal::Integer
   attribute :c_array?, Types::Array
   attribute :d_hash?, Types::Hash
   


   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
__END__
CREATE PROPERTY my_emb.a_string STRING
CREATE PROPERTY my_emb.b_int    Integer
CREATE PROPERTY my_emb.a_array LIST
CREATE PROPERTY my_emb.a_hash  MAP


