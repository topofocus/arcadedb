module Arcade
  module Support
    module Array
      # Class  extentions to manage to_db and from_db
      def to_db
        if all?{ |x| x.respond_to?(:rid?)}  && any?( &:rid? )
          "["+ map{|x| x.rid? ? x.rid : x.to_or }.join(', ') + ']'
        else
          map(&:to_db) # .join(',')
        end
      end

      def to_or
        "["+ map( &:to_or).join(', ')+"]"
      end

      def from_db
        map &:from_db
      end

      def to_human
        map &:to_human
      end

      # used to enable
      # def abc *key
      # where key is a Range, an comma separated List or an item
      # aimed to support #compose_where
      def analyse # :nodoc:
        if first.is_a?(Range)
          first
        elsif size ==1
          first
        else
          self
        end
      end

      def arcade_flatten
        while( first.is_a?(Array) )
          self.flatten!(1)
        end
        self.compact!
        self ## return object
      end


      # chainable model-extaction  method
      #
      # Used to get the results of a query where a projection is specified
      # q =  DB.query(" select <projection> from ...")  -->  [<projection> => [ { result (hash) } , ... ]]
      # q.select_result( <projection> )                 -->  An array or plain results  or
      #                                                 -->  an array of Arcade::Base-objects
      #

      def select_result condition=nil
        condition = first.keys.first if condition.nil?
        map{|x| x[condition.to_sym]}.flatten.allocate_model
      end

      # convert query results into  Arcade::Base-objects
      #  handles  [query: => [{ result }, {result} ], too

      def allocate_model autoload=false
        if size==1 && first.is_a?( Hash ) && !first.keys.include?( :@type )
            # Load only the associated record, not the entire structure
            first.values.flatten.map{ |x| x.allocate_model(false) }
        else
          map{ |x| _allocate_model x, autoload }
        end
      end
    end
  end
end

class Array
  include Arcade::Support::Array
  include Arcade::Support::Model  #  mixin allocate_model

  @@accepted_methods = [:"_allocate_model"]
  ## dummy for refining

  # it is assumed that the first element of the array acts
  # as master . 
	def method_missing method, *args, &b
		return if [:to_hash, :to_str].include? method
    if @@accepted_methods.include?( method ) || first.invariant_attributes.include?( method )
      self.map{ |x| x.public_send method, *args, &b }
    else
      raise ArgumentError.new("Method #{method} does not exist in class #{first.class}")
    end
	end

end

module Arcade
  module Support
    module Symbol
      def to_a
        [ self ]
      end
      # symbols are masked with ":{symbol}:"
      def to_db
        ":" + self.to_s + ":"
      end
      def to_or
        "'" + self.to_db + "'"
      end

    end

    module Object
      def from_db
        self
      end

      def to_db
        self
      end

      def to_or
        self
      end

      def rid?
        false
      end
    end

    module  Time
      def to_or
        "DATE(#{self.to_datetime.strftime('%Q')})"
      end
    end

    module Date
      def to_db
        if RUBY_PLATFORM == 'java'
          java.util.Date.new( year-1900, month-1, day , 0, 0 , 0 )  ## Jahr 0 => 1900
        else
          self
        end
      end
      def to_or
        "\"#{self.to_s}\""
      # "DATE(\'#{self.to_s}\',\'yyyy-MM-dd\')"
      #  "DATE(#{self.strftime('%Q')})"
      end
     # def to_json
     #   "DATE(#{self.strftime('%Q')})"
     # end
    end
    module DateTime
      def to_or
        "DATE(#{self.strftime('%Q')})"
      end
    end
    module Numeric

      def to_or
        # "#{self.to_s}"
        self
      end

      def to_a
        [ self ]
      end

      def rid?
       nil
      end
    end

    module Hash

      # converts :abc => {anything} to "abc" => {anything}
      #
      # converts nn => {anything} to nn => {anything}
      #
      # leaves "abc" => {anything} untouched
      def to_db   # converts hast from activeorient to db
        map do | k, v|
          orient_k =  case k
                      when Numeric
                        k
                      when Symbol, String
                        k.to_s
                      else
                        raise "not supported key: #[k} -- must a sting, symbol or number"
                      end
          [orient_k, v.to_db]
        end.to_h
      end
      #
      def from_db
        # populate the hash by converting keys: stings to symbols, values: preprocess through :from_db
        map do |k,v|
          orient_k = if  k.to_s.to_i.to_s == k.to_s
                       k.to_i
                     else
                       k.to_sym
                     end

          [orient_k, v.from_db]
        end.to_h
      end

      def to_human
        "< " + map do  | k,v |
          vv = v.is_a?( Arcade::Base ) ? v.to_human[1..-2] :  v.to_s
           k.to_s + ": "  + vv
        end.join( "\n    " ) + " >"
      end

      def allocate_model( autoload = Config.autoload )
        _allocate_model( self , autoload )
      end



      # converts a hash to a string appropiate to include in raw queries
      def to_or
        "{ " + to_db.map{|k,v| "#{k.to_or}: #{v.to_or}"}.join(',') + "}"
      end
    end


    module String2

      # from db translates the database response into active-orient objects
      #
      # symbols are representated via ":{something]:}"
      #
      # database records respond to the "rid"-method
      #
      # other values are not modified
      def from_db
        if rid?
          Arcade::Init.db.get  self
        elsif  self =~ /^:.*:$/
          # symbol-representation in the database
          self[1..-2].to_sym
        else
          self
        end
      end

      alias expand from_db
      # if the string contains "#xx:yy" omit quotes
      def to_db
        rid? ? "#"+rid : self   # return the string (not the quoted string. this is to_or)
      end

      def to_or
        quote
      end
    end
  end
end


Symbol.include Arcade::Support::Symbol
Numeric.include Arcade::Support::Numeric
Object.include Arcade::Support::Object
Time.include Arcade::Support::Time
Date.include Arcade::Support::Date
DateTime.include Arcade::Support::DateTime
String.include Arcade::Support::String2
class Hash
  include Arcade::Support::Model  #  mixin allocate_model
  include Arcade::Support::Hash
end

class NilClass
	def to_or
		"NULL"
	end
end








