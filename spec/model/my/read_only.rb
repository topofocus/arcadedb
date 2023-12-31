
module My
  class  ReadOnly < Arcade::Vertex
    attribute :node?, Types::Nominal::Integer
    attribute :a?, Types::Nominal::String
   attribute :b?, Types::Nominal::Integer
   attribute :c?, Types::Nominal::Array
   attribute :d?, Types::Nominal::Hash

   ## make database immutable
   not_permitted :update, :update!, :upsert, :delete
  end
end
