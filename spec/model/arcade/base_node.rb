module Arcade
  class BaseNode < Vertex
    attribute :item?, Types::String
   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
__END__
CREATE PROPERTY base_node.item STRING
CREATE INDEX `BaseNode[item]` ON base_node (item) UNIQUE
