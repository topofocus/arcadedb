module Arcade
  class  Revision < Arcade::Vertex
    attribute :protocol?, Types::Nominal::Array

    @@u='root'  # default user
    @@i = 'Record initiated'

  def self.set_user u
    @@u = u
  end

  def self.set_initial_message m
    @@i = m
  end

  def self.insert **attr

    action = block_given? ?  yield : @@i
    i= super **attr
    i.update_list :protocol,
                   Arcade::RevisionRecord.create( user: @@u, action: action ),
                   modus: :first
    i.refresh

  end


  def update **attr
    hist_state =  attr.keys.map do |k|
                  [ k,  send( k ) ]
    end.to_h
    super **attr
    revision = if block_given?
         Arcade::RevisionRecord.create( user: @@u, action: yield,  fields: hist_state )
               else
                 Arcade::RevisionRecord.create( fields: hist_state )
               end
    update_list :protocol, revision, modus: :append
  end
  end
end
