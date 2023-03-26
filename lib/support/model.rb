module Arcade
  module Support
    module Model

      def resolve_edge_name edge_name
        case  edge_name
        when nil
          ""
        when Class
          "'" + edge_name.database_name + "'"
        when String
          "'" + edge_name + "'"
        end
      end


    #  used by array#allocate_model
      def _allocate_model response=nil, auto = Config.autoload

      if response.is_a? Hash
        # save rid to a safe place
        temp_rid = response.delete :"@rid"

        return response if temp_rid.rid?.nil?
        # extract type infos  and convert to database-name
        type           = response.delete :"@type"
        cat            = response.delete :"@cat"
        n, type_name = type.camelcase_and_namespace
        n = self.namespace if n.nil?
        # autoconvert rid's in attributes to model-records  (exclude edges!)
        if auto && !(cat.to_s =='e')
          response.transform_values! do  |x|
            case x
            when String
              x.rid? ?  x.load_rid : x
            when Array
              x.map{ | y | y.rid? ?  y.load_rid(false) : y }   # do not autoload further records, prevents from recursive locking
            when Hash
              if x.include?(:@type)
                x.merge( rid: '#0:0' ).allocate_model(false)
              else
                x.transform_values!{|z|  z.rid? ?  z.load_rid(false) : z }
              end
            else
              x
            end
          end
        end
        # choose the appropriate class
        klass=  Dry::Core::ClassBuilder.new(  name: type_name, parent:  nil, namespace:  n).call
        #
      begin
        # create a new object of that  class with the appropriate attributes
        new = klass.new  **response.merge( rid: temp_rid || "#0:0" )  # #0:0 --> embedded model records
      rescue ::ArgumentError => e
        raise  "Allocation of class #{klass.to_s} failed"
      end
        # map additional attributes to `input`
        v =  response.except  *new.attributes.keys
        v.empty? ?  new  :  new.new( values: v.except( :"@in", :"@out" ) )
     elsif response.is_a? Array
       puts "Allocate_model..detected array"
       ## recursive behavior, just in case
       response.map{ | y | _allocate_model y }
     elsif response.rid?
       # Autoload rid's
       response.load_rid
     else
       response
      end
    end
    end
  end
end
