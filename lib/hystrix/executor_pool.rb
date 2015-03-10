require 'singleton'
require 'securerandom'

module Hystrix
	class CommandExecutorPools
		include Singleton

		attr_accessor :pools, :lock

		def initialize
			self.lock = Mutex.new
			self.pools = {}
		end

		def get_pool(pool_name, size = nil)
			lock.synchronize do
				pools[pool_name] ||= CommandExecutorPool.new(pool_name, size || 10)
				pools[pool_name].set_size(size || 10)

				return pools[pool_name]
			end
		end

		def shutdown
			lock.synchronize do
				for pool_name, pool in pools
					pool.shutdown
				end
			end
		end
	end

	class CommandExecutorPool
		attr_accessor :name, :size
		attr_accessor :executors, :locked_executors, :lock
		attr_accessor :circuit_supervisor
		attr_reader :uuid

		def initialize(name, size)
			@uuid = SecureRandom.uuid

			self.name = name
			self.size = size
			self.executors = {}
			self.locked_executors = {}
			self.lock = Mutex.new
			self.circuit_supervisor = Circuit.supervise
			size.times do
				e = CommandExecutor.new(self)
				self.executors[e.uuid] = e
			end
		end

		def set_size(size)
			self.size = size
			if size > self.size
				(size - self.size).times do
					e = CommandExecutor.new(self)
					self.executors[e.uuid] = e
				end
				self.size = size
			end
		end

		def take
			raise ExecutorPoolFullError.new("Unable to get executor from #{self.name} pool. [#{self.locked_executors.size} locked] [#{@uuid}]") unless self.executors.count > 0

			lock.synchronize do
				raise ExecutorPoolFullError.new("Unable to get executor from #{self.name} pool. [#{self.locked_executors.size} locked] [#{@uuid}]") unless self.executors.count > 0
				uuid, executor = self.executors.first
				executor.lock

				self.executors.delete(executor.uuid)
				self.locked_executors[executor.uuid] = executor

				return executor
			end
		end

		def release(executor)
			self.locked_executors.delete(executor.uuid)
			self.executors[executor.uuid] = executor
		end

		def shutdown
			lock.synchronize do
				self.executors = {}
				until (self.executors.size + self.locked_executors.size) == 0 do
					self.executors = {}
					sleep 0.1
				end
			end
		end
	end

	class CommandExecutor
		attr_accessor :owner
		attr_reader :uuid, :pool

		def initialize(pool)
			@uuid = SecureRandom.uuid
			@pool = pool

			self.owner = nil
		end

		def lock
			self.owner = Thread.current
		end

		def unlock
			self.owner = nil
			self.pool.release(self) if self.pool
		end
		
		def locked?
			!self.owner.nil?
		end

		def run(command)
			command.run
		end
	end
end