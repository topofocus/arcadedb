module Arcade
  class UniqEdge <  Edge

    def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
##
__END__
CREATE INDEX  ON uniq_edge ( `@in`,`@out` )  UNIQUE

