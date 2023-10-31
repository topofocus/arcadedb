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
  end
end
