require 'encrypted_sidekiq_redis'
require 'sidekiq_logger_formatter'
require 'worker_health_checker'

Sidekiq::Logging.logger.level = Logger::WARN
Sidekiq::Logging.logger.formatter = SidekiqLoggerFormatter.new

# cloud.gov redis compatibility
# centralize this in redis initializer?
if ENV['VCAP_SERVICES']
  services = JSON.parse(ENV['VCAP_SERVICES'])
  credentials = services['redis32'].first['credentials']
  redis_url = "redis://:#{credentials['password']}@#{credentials['hostname']}:#{credentials['port']}"
else
	redis_url = Figaro.env.redis_url
end

redis_connection = proc do
  EncryptedSidekiqRedis.new(url: redis_url)
end

size = (Sidekiq.server? ? (Sidekiq.options[:concurrency] + 2) : 5)

Sidekiq.configure_server do |config|
  config.redis = ConnectionPool.new(size: size, &redis_connection)

  # NOTE: Sidekiq does not run middleware in tests by default. Make sure to also add
  # middleware to spec/rails_helper.rb to run in tests as well
  config.server_middleware do |chain|
    chain.add WorkerHealthChecker::Middleware
  end
end

Sidekiq.configure_client do |config|
  config.redis = ConnectionPool.new(size: size, &redis_connection)
end
