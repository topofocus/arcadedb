module Arcade
  class Timeseries < Arcade::Base
    # base class for user model classes; behaviour lives in Arcade::Timeseries (lib/arcade/timeseries.rb)
    # the constant Arcade::Timeseries IS this class — the arcade-side file reopens it with full behaviour.
  end
end
