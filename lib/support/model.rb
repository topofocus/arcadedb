module Arcade
  module Support
    module Model

    def allocate_model response
      puts "Response #{response}"  # debugging

      if response.is_a? Hash
        ## save rid to a safe place
        temp_rid = response.delete :"@rid"
        return response unless temp_rid.rid?
        # convert edge infos if available
        response[:in]   = response.delete(:"@in") if response[":@in"]
        response[:out]  = response.delete(:"@out") if  response[":@out"]
        # extract type infos  and convert to database-name
        type           = response.delete :@type
        n, type_name = type.camelcase_and_namespace
        n = self.namespace if n.nil?
        # remove internal attributes
        response =  response.except :"@type", :"@cat", :"@rid", :"@in", :"@out"
        ## autoconvert rid's in attributes to model-records
        response.transform_values! do  |x|
          case x
          when String
            x.rid? ?  x.load_rid : x
          when Array
            x.map{|y| y.rid? ?  y.load_rid : y }
          when Hash
            x.transform_values{|z| z.rid? ? z.load_rid : z }
          else
            x
          end
        end
        #
        # choose the appropriate class
        #
        klass=  Dry::Core::ClassBuilder.new(  name: type_name, parent:  nil, namespace:  n).call
        #
        # create a new object of that  class with the appropriate attributes
#        puts "response: #{response.inspect}"   # debugging
        new = klass.new  **response.merge( rid: temp_rid )
        v =  response.except  *new.attributes.keys
        new.new( values: v ) unless v.empty?
     elsif response.is_a? Array
       ## recursive behavior, just in case
       response.map{|y| allocate_model y}
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
