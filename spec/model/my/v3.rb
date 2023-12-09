module My
  class  V3  < V1
    attribute( :datum, Types::Date.constructor do |value|
             if value.is_a?(Integer)
                       # Assuming the malformatted integer represents a timestamp in seconds
                       timestamp = Time.at(value / 1000)
                       Date.parse(timestamp.to_s)
              else
                Date.parse value
              end
     end)
   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
##
__END__
CREATE PROPERTY my_v3.datum DATE
Create Index on my_v3 ( datum ) NOTUNIQUE
