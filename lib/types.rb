module Types
  include Dry.Types()

  # include in attribute definitions
  Rid = String.constrained( format:  /\A[#]{1}[0-9]{1,}:[0-9]{1,}\z/ )
  Blockchain =  String.constrained( format: /^(algo|eth|btc)$/ )  #  add other blockchain symbols here
  Email = String.constrained( format: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i )


  # Define a type for your DateTime with timezone.  Crucially, use
# the `.constructor` to handle the string parsing and potential errors. (source: Gemini)
Types::DateTime = Types::Any.constructor do |value|
  begin
    case value
      when String
    ::DateTime.parse(value)
      when Integer
      ::Time.at(value).to_datetime
      else
      ::DateTime.now
    end
  rescue ArgumentError
    # Handle invalid date strings.  Options:
    # 1. Raise an exception (recommended for API responses)
    raise Dry::Types::CoercionError.new(
      value, DateTime, "Invalid DateTime format: #{value}"
    )
    # 2. Return nil (less strict, but might lead to unexpected behavior)
    # nil
    # 3. Use a default value (be careful with this, as it might mask errors)
    # DateTime.now
  end
end

end
