module Arcade
  class RevisionRecord  < Document
    attribute  :user, Types::Nominal::String.default( 'root'.freeze )
    attribute  :action, Types::Nominal::String.default( "Property changed".freeze )
    attribute  :date, Types::Nominal::Date.default( Date.today.freeze )
    attribute  :fields?, Types::Nominal::Hash

   #  Revision Records are always embedded.
   #  create and insert methods return an new ruby record
   def self.create **attr
     new **( { rid: '#0:0', date: Date.today}.merge attr )
   end
   def self.insert **attr
     new **( { rid: '#0:0', date: Date.today}.merge **attr )
   end

=begin
  Its not allowed to delete records.
=end
    def self.delete where: {} , **args
      raise ArcadeQueryError, "Its not possible to delete revision records"
    end

    def delete
      raise ArcadeQueryError, "Its not possible to delete revision records"
    end

  end
end
