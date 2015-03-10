module Hystrix
	class Configuration
		def self.on_success(&block)
			@on_success = block
		end
		def self.notify_success(params)
			if @on_success
				@on_success.call(params)
			end
		end

		def self.on_fallback(&block)
			@on_fallback = block
		end
		def self.notify_fallback(params)
			if @on_fallback
				@on_fallback.call(params)
			end
		end

		def self.on_failure(&block)
			@on_failure = block
		end
		def self.notify_failure(params)
			if @on_failure
				@on_failure.call(params)
			end
		end

		def self.reset
			@on_success = nil
			@on_fallback = nil
			@on_failure = nil
		end
	end
end