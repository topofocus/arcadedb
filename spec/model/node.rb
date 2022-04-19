module Arcade
  class Node < Vertex
    attribute :item?, Types::Integer

    def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
__END__
CREATE PROPERTY node.item INTEGER
CREATE INDEX `NodeItemidx` ON node (item)  NOTUNIQUE

