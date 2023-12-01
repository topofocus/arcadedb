module Arcade
  class Document  <  Base
   # schema schema.strict    #  -- throws an error if  specified keys are missing

    ## has to be overloaded
   # def accepted_methods
   #
   # end
   def self.create **attributes
     Api.create_document  db.database, database_name, session_id: db.session,  **attributes
   end

=begin
    Document.delete fires a "delete vertex" command to the database.
    To remove all records  use  »all: true« as argument

    The "where" parameter is optional
=end
    def self.delete where: {} , **args
      if args[:all] == true
        where = {}
      else
        where.merge!(args) if where.is_a?(Hash)
        return 0 if where.empty?
      end
      # query returns [{count => n }]
      #  puts "delete from  #{database_name} #{compose_where(where)}"
      db.transmit { "delete  from `#{database_name}` #{compose_where(where)}"   } &.first[:count] rescue 0
    end

  end
end
