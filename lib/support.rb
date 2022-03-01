module Arcade
  module Support
    module String
      #modified version of
       # https://stackoverflow.com/questions/63769351/convert-string-to-camel-case-in-ruby
      # returns an Array [ Namespace(first charater upcase)  , Type(class, camalcase) ] 
      def camelcase_and_namespace
        if  self.count("_")  >= 1 || self.count('-') >=1
          delimiters = Regexp.union(['-', '_'])
          self.split(delimiters).then { |first, *rest| [first.tap {|s| s[0] = s[0].upcase}, rest.map(&:capitalize).join]  }
        else
          [ nil, self.capitalize ]
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
    end
  end
end

String.include Arcade::Support::String
