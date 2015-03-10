require 'spec_helper'

describe Hystrix::Configuration do
	after do
		Hystrix::Configuration.reset
	end

	it 'defines callbacks via dsl' do
		Hystrix.configure do
			on_success do |params|
				raise 'callback'
			end
		end

		expect {
			Hystrix::Configuration.notify_success({})
		}.to raise_error('callback')
	end
end