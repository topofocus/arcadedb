module  Ex
  class  DependOn < Arcade::Edge
    attribute :married?, Types::Nominal::Bool



   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
##
# Add Contrains to the edge
__END__
CREATE INDEX depends_out_in ON ex_depend_on  (`@out`, `@in`) UNIQUE
