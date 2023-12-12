#require 'active_support/inflector'

module Arcade
  module Support
    module Sql

=begin
supports
  where: 'string'
  where: { property: 'value', property: value, ... }
  where: ['string, { property: value, ... }, ... ]

Used by update and select

_Usecase:_
  compose_where 'z=34', u: 6
  => "where z=34 and u = 6" 
=end

      def compose_where *arg , &b
        arg = arg.flatten.compact

        unless arg.blank? 
          g= generate_sql_list( arg , &b)
          "where #{g}" unless g.empty?
        end
      end

=begin
designs a list of "Key =  Value" pairs combined by "and" or the binding  provided by the block
   ORD.generate_sql_list  where: 25 , upper: '65'
    => "where=25 and upper='65'"
   ORD.generate_sql_list(  con_id: 25 , symbol: :G) { ',' }
    => "con_id=25 , symbol='G'"

If »NULL« should be addressed, { key: nil } is translated to "key = NULL"  (used by set:  in update and upsert),
{ key: [nil]  } is translated to "key is NULL" ( used by where )

=end
      def generate_sql_list attributes = {},  &b
        fill = block_given? ? yield : 'and'
        case attributes
        when ::Hash
          attributes.map do |key, value|
            case value
            when nil
              "#{key}=NULL"
            when ::Array
              if value == [nil]
                "#{key} is NULL"
              else	
                "#{key} in #{value.to_db}"
              end
            when Range
              "#{key} between #{value.first.to_or} and #{value.last.to_or} "
            else #  String, Symbol, Time, Trueclass, Falseclass ...
              "#{key}=#{value.to_or}"
            end
          end.join(" #{fill} ")
        when ::Array
          attributes.map{|y| generate_sql_list y, &b }.join( " #{fill} " )
        when String
          attributes
        when Symbol, Numeric
          attributes.to_s
        end
      end


      # used both in Query and MatchConnect
      # while and where depend on @q, a struct
    end  # module
  end # module
end # modul
