module Arcade
  module Support
    module Object
      # this is the rails method
       def present?
         !blank?
       end

       # File activesupport/lib/active_support/core_ext/object/blank.rb, line 46
       def presence
          self if present?
       end
       # File activesupport/lib/active_support/core_ext/object/blank.rb, line 19
       def blank?
         respond_to?(:empty?) ? !!empty? : !self
       end
    end
  end
end
Object.include Arcade::Support::Object
