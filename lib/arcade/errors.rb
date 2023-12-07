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

  class ImmutableError < RuntimeError
  end
  class IndexError < RuntimeError
  end

  class RollbackError < RuntimeError
  end

  class QueryError < RuntimeError
    attr_reader :error, :args
    def initialize  error: "", detail: "", exception: "", **args
      @error = error
#      @detail = detail
      @args = args
      @exception = exception
      super detail
    end
  end

  # used by Dry::Validation,  not covered by "error"
  class InvalidParamsError < StandardError
    attr_reader :object
    # @param [Hash] object that contains details about params errors.
    # # @param [String] message of the error.
    def initialize(object, message)
      @object = object
      super(message)
    end
  end

end # module  Arcade

# Patching Object with universally accessible top level error method. 
# The method is used throughout the lib instead of plainly raising exceptions. 
# This allows lib user to easily inject user-specific error handling into the lib 
# by just replacing Object#error method.
#def error message, type=:standard, backtrace=nil
#  e = case type
#  when :standard
#    Arcade::Error.new message
#  when :args
#    Arcade::ArgumentError.new message
#  when :symbol
#    Arcade::SymbolError.new message
#  when :load
#    Arcade::LoadError.new message
#  when :immutable
#    Arcade::ImmutableError.new message
#  when :commit
#    Arcade::RollbackError.new message
#  when :query
#    Arcade::QueryError.new message
#  when :args
#    IB::ArgumentError.new message
#  when :flex
#    IB::FlexError.new message
#  when :reader
#    IB::TransmissionError.new message
#  when :verify
#    IB::VerifyError.new message
#  end
#  e.set_backtrace(backtrace) if backtrace
#  raise e
#end
