module Arcade
  class Connects < Edge
   attribute :basic?, Types::Nominal::Any
   attribute :extra?, Types::Nominal::Any
   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
# This works but slows down the process
#CREATE PROPERTY connects.in LINK
#CREATE PROPERTY connects.out LINK
#CREATE INDEX `Connects[idx]` ON connects ( in, out )  UNIQUE
__END__
