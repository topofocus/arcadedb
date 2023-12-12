module Arcade
  module Support
    module Model

      def resolve_edge_name *edge_names
        edge_names.map do | edge_name |
          case  edge_name
          when nil
            ""
          when Class
            "'" + edge_name.database_name + "'"
          when String
            "'" + edge_name + "'"
          end
        end.join(',')
      end


    #  used by array#allocate_model
      def _allocate_model response=nil, auto = Config.autoload


      if response.is_a? Hash
        # save rid to a safe place
        temp_rid = response.delete :"@rid"
        type     = response.delete :"@type"
        cat      = response.delete :"@cat"

        return response if type.nil?
        temp_rid = "#0:0" if temp_rid.nil?
        type = "d" if type.nil?
        # extract type infos  and convert to database-name
        namespace, type_name = type.camelcase_and_namespace
        namespace = self.namespace if namespace.nil?
        # autoconvert rid's in attributes to model-records  (exclude edges!)
        if auto && !(cat.to_s =='e')
          response.transform_values! do  |x|
            case x
            when String
              x.rid? ?  x.load_rid : x                   # follow links
            when Array
              a =[]
              x.map do| y |
                # Thread.new do  ## thread or fiber decrease the performance significantly.
                  if y.is_a?(Hash) && y.include?(:@type)   # if embedded documents are present, load them
                    y.allocate_model(false)
                  elsif y.rid?                             # if links are present, load the object
                    y.load_rid(false) # do not autoload further records, prevents from recursive locking
                  else
                    y
                  end
               # end
              end
            when Hash
              if x.include?(:@type)
                #x.allocate_model(false)
                _allocate_model(x,false)
              else
                x.transform_values!{|z|  z.rid? ?  z.load_rid(false) : z }
              end
            else
              x
            end
          end
        end
        # choose the appropriate class
        klass=  Dry::Core::ClassBuilder.new(  name: type_name, parent: nil, namespace: namespace ).call
        #
      begin
        # create a new object of that  class with the appropriate attributes
        new = klass.new  **response.merge( rid: temp_rid  )
      rescue ::ArgumentError => e
        raise  "Allocation of class #{klass.to_s} failed"
      end
        # map additional attributes to `input`
        v =  response.except  *new.attributes.keys
        v.empty? ?  new  :  new.new( values: v.except( :"@in", :"@out" ) )
     elsif response.is_a? Array
       puts "Allocate_model..detected array"
       ## recursive behavior, just in case
       response.map{ | y | _allocate_model y, auto }
     elsif response.rid?
       # Autoload rid's
       response.load_rid
      # auto ? response.load_rid : response
     else
       response
      end
    end
    end
  end
end
