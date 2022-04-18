module Arcade
  module Support
    module Model

    def allocate_model response
#      puts "Response #{response}"  # debugging

      if response.is_a? Hash
        response[:rid] = response.delete :"@rid"
      #  if response[:"@type"] == "e"
          response[:in]   = response.delete(:"@in")
          response[:out]  = response.delete(:"@out")
      #  end
        type           = response.delete :@type
        n, type_name = type.camelcase_and_namespace
        n = self.namespace if n.nil?
        response =  response.except :"@type", :"@cat", :"@rid", :"@in", :"@out"                   # remove internal attributes
        # choose the appropriate class
        #
        klass=  Dry::Core::ClassBuilder.new(  name: type_name, parent:  nil, namespace:  n).call
        # create a new object of that  class with the appropriate attributes
        new = klass.new  **response
        v =  response.except  *new.attributes.keys
        new = new.new( values: v ) unless v.empty?
        new
      #else
      #  raise "Dataset #{rid} is either not present or the database connection is broken"
     elsif response.is_a? Array
       response.map{|y| allocate_model y}
      end
    end
    end
  end
end
