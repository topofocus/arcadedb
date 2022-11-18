module Arcade
  class ExtraNode < Node
    attribute :extraitem?, Types::String
    def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
__END__
CREATE PROPERTY extra_node.extraitem STRING
CREATE INDEX  ON extra_node (extraitem) UNIQUE
