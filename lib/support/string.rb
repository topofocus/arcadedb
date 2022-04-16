module Arcade
  module Support
    module String
      #modified version of
       # https://stackoverflow.com/questions/63769351/convert-string-to-camel-case-in-ruby
      # returns an Array [ Namespace(first character upcase)  , Type(class, camelcase) ]
      #
      #  if the namespace is not found, joins all string-parts
      def camelcase_and_namespace
        if  self.count("_")  >= 1 || self.count('-') >=1
          delimiters = Regexp.union(['-', '_'])
          n,c= self.split(delimiters).then { |first, *rest| [first.tap {|s| s[0] = s[0].upcase}, rest.map(&:capitalize).join]  }
          namespace_present =  Object.const_get(n)  rescue  false # Database.namespace
          # if no namespace is found, leave it empty and return the capitalized string as class name
          namespace_present && !c.nil? ? [namespace_present,c] : [Database.namespace, n+c]
        else
          [ Database.namespace, self.capitalize ]
        end
      end

      def snake_case
        n= if split('::').first == Database.namespace.to_s
           split('::')[1..-1].join
         else
           split("::").join
         end
       n.gsub(/([^\^])([A-Z])/,'\1_\2').downcase
      end

      def capitalize_first_letter
        self.sub(/^(.)/) { $1.capitalize }
      end
  # a rid is either #nn:nn or nn:nn
      def rid?
        self =~ /\A[#]{,1}[0-9]{1,}:[0-9]{1,}\z/
      end
#  return a valid rid (format: "nn:mm") or nil
      def rid
        self["#"].nil? ? "#"+ self : self if rid? 
      end

      def where **args
        if rid?
          from_db.where **args
        end
      end
      def to_a
        [ self ]
      end

      def quote
        str = self.dup
        if str[0, 1] == "'" && str[-1, 1] == "'"
          self
        else
          last_pos = 0
          while (pos = str.index("'", last_pos))
            str.insert(pos, "\\") if pos > 0 && str[pos - 1, 1] != "\\"
            last_pos = pos + 1
          end
          "'#{str}'"
        end
      end

      ## Load the database object if the string is a rid
      def load_rid
        db.get self if rid?  rescue nil
      end

      # updates the record and returns the modified dataset
      def update **args
        r=   Arcade::Query.new( from: self , kind: :update, set: args).execute
        r= r.pop if r.is_a?( Array ) 
        r[:"$current"].load_rid
      end

      def to_human
        self
      end
      private
      def db
        Arcade::Init.db
      end
    end
  end
end

String.include Arcade::Support::String

module Types
    include Dry.Types()

      Rid = String.constrained( format:  /\A[#]{1}[0-9]{1,}:[0-9]{1,}\z/ )
end
