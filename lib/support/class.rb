module Arcade
  module Class
    def demodulize
      a, *b = to_s.split("::")
      if b.empty? 
        a
      else
        b.join('::')
      end
    end
  end
end
Class.include Arcade::Class
