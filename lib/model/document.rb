module Arcade
  class Document  <  Base
   # schema schema.strict    #  -- throws an error if  specified keys are missing

    def self.create  **attributes
        Database.database.execute { " create document #{self.database_name} " }    
      end
    
  end
end
