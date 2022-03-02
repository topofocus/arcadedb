module Arcade
  module Support
    module String
      #modified version of
       # https://stackoverflow.com/questions/63769351/convert-string-to-camel-case-in-ruby
      # returns an Array [ Namespace(first charater upcase)  , Type(class, camalcase) ]
      #
      #  if the namespace is not found, joins all string-parts
      def camelcase_and_namespace
        if  self.count("_")  >= 1 || self.count('-') >=1
          delimiters = Regexp.union(['-', '_'])
          n,c= self.split(delimiters).then { |first, *rest| [first.tap {|s| s[0] = s[0].upcase}, rest.map(&:capitalize).join]  }
          namespace_present =  Object.const_get(n)  rescue  false # Database.namespace
          namespace_present && !c.nil? ? [n,c] : [Database.namespace, n+c]
        else
          [ Database.namespace, self.capitalize ]
        end
      end
      ## activesupport solution
#      def camelize(uppercase_first_letter = true)
#        string = self
#        if uppercase_first_letter
#          string = string.sub(/^[a-z\d]*/) { |match| match.capitalize  }
#        else
#          string = string.sub(/^(?:(?=\b|[A-Z_])|\w)/) { |match| match.downcase  }
#        end
#        string.gsub(/(?:_|(\/))([a-z\d]*)/) { "#{$1}#{$2.capitalize}"  }.gsub("/", "::")
#      end
      def rid?
        self =~ /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      end
      def rid
        self["#"].nil? ? "#"+ self : self if rid? 
      end
    end
  end
end

String.include Arcade::Support::String


module Types
    include Dry.Types()

      Rid = String.constrained( format:  /\A[#]{1}[0-9]{1,}:[0-9]{1,}\z/ )
end
