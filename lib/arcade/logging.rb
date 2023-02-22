#require_relative 'default_formatter'
module Arcade
	module Logging
		def self.included(base)
			base.extend ClassMethods
			base.send :define_method, :logger do
				base.logger
			end
		end

		module ClassMethods
			def logger
				@logger
			end

			def logger=(logger)
				@logger = logger
			end

			def configure_logger(log= STDOUT)
        if log.is_a? Logger
					@logger = log
				else
					@logger = Logger.new log
        end
        @logger.level = Logger::INFO
        @logger.formatter = DefaultFormatter
      end
		end

	class DefaultFormatter < Logger::Formatter
		def self.call(severity, time, program_name, msg)
			"#{time.strftime("%d.%m.(%X)")}#{"%5s" % severity}->#{msg}\n"
		end
	end
end
end
# source: https://github.com/jondot/sneakers/blob/master/lib/sneakers/concerns/logging.rb
