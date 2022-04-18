module Arcade

  # Error handling
  class Error < RuntimeError
  end

  class ArgumentError < ArgumentError
  end

  class SymbolError < ArgumentError
  end

  class LoadError < LoadError
  end


  class RollbackError < RuntimeError
  end

end # module  Arcade

# Patching Object with universally accessible top level error method. 
# The method is used throughout the lib instead of plainly raising exceptions. 
# This allows lib user to easily inject user-specific error handling into the lib 
# by just replacing Object#error method.
def error message, type=:standard, backtrace=nil
  e = case type
  when :standard
    Arcade::Error.new message
  when :args
    Arcade::ArgumentError.new message
  when :symbol
    Arcade::SymbolError.new message
  when :load
    Arcade::LoadError.new message
  when :commit
    Arcade::RollbackError.new message
  end
  e.set_backtrace(backtrace) if backtrace
  raise e
end
