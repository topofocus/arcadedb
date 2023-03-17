module  Ex
  class  Human < Arcade::Vertex
    attribute :name, Types::String
    attribute :birth?, Types::Nominal::Date 
    attribute :married?, Types::Nominal::Bool


    # parents are by humans with childen
    # we search for childen and display the connected dataset
    def self.parents **args                                                # The method accepts
      q= query( **args.merge(  where: { married: false  }))                     # all married humans
      # ruby solution
      #potential_parents = q.query.allocate_model                          # execute query & make model-objects
      #real_parents =  potential_parents.map( &:out ).flatten              # any out-node present is a child
      # database solution
      q.projection 'in()'                                   # select out() from ex_human where married = true
      q.query.select_result 'in()'
    end

    #  children are humans with parents
    # we serach for merried humans and diplay their dependends
    def self.children **args
      q= query( **args.merge( where:{ married: true  }))                  # all married humans
      # ruby solution
      #potential_children = q.query.allocate_model                          # execute query & make model-objects
      #real_childs =  potential_children.map( &:in ).flatten                # any in-node present is a child
      q.projection 'out()'
      q.query.select_result 'out()'
    end

   def self.db_init
      File.read(__FILE__).gsub(/.*__END__/m, '')
    end
  end
end
## The code below is executed on the database after the database-type is created
## Use the output of `ModelClass.database_name` as DB type  name
## 
__END__
CREATE PROPERTY ex_human.name STRING
CREATE PROPERTY ex_human.married BOOLEAN
CREATE INDEX  ON ex_human ( name ) UNIQUE
