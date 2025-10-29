RSpec.configure do |config|
  config.before(:each) do
    # Replace Redis instances with MockRedis for testing
    # This prevents tests from using real Redis
    redis_mock = MockRedis.new

    # Mock REDIS_CACHE ConnectionPool
    allow(REDIS_CACHE).to receive(:with).and_yield(redis_mock) if defined?(REDIS_CACHE)

    # Mock REDIS_SESSION ConnectionPool
    allow(REDIS_SESSION).to receive(:with).and_yield(redis_mock) if defined?(REDIS_SESSION)

    # Mock Redis.current for legacy code
    Redis.current = redis_mock
  end

  config.after(:each) do
    # Clean up Redis mock data after each test
    Redis.current.flushdb if Redis.current.is_a?(MockRedis)
  end
end
