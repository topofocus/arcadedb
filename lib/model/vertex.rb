module Arcade
  class Vertex  < Base

#    include Arcade::Support::Sql
=begin
Vertex.delete fires a "delete vertex" command to the database.

To remove all records  use  »all: true« as argument

To remove a specific rid, use  rid: "#nn:mmm" as argument

=end
    def self.delete where: {} , **args
      if args[:all] == true 
        where = {}
      elsif args[:rid].present?
        return db.execute { "delete vertex #{args[:rid]}" }.first["count"]
      else
        where.merge!(args) if where.is_a?(Hash)
        return 0 if where.empty?
      end
      # query returns [{count => n }]
      db.execute { "delete vertex #{database_name} #{compose_where(where)}"  }.first["count"] rescue 0
    end

  end
end
