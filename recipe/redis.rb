# Redis / Valkey Configuration Recipe
#
# A Ruby client library for Valkey/Redis.
# https://github.com/redis/redis-rb
#
# This template uses Valkey by default (BSD-3 licensed, fully open source).
# Valkey is 100% protocol-compatible with Redis and is a drop-in replacement.
#
# Key facts about Valkey (2025):
# - Backed by Linux Foundation (AWS, Google, Oracle)
# - 100% compatible with Redis 7.2 APIs
# - Better performance (3x throughput in Valkey 8.0)
# - Fully open source (BSD-3), no licensing concerns
# - redis-rb gem officially supports Valkey 7.2+, 8.x

gem "redis"

# Connection pooling for Valkey/Redis (required for ActionCable and multi-threaded servers)
# https://github.com/mperham/connection_pool
gem "connection_pool"

# Map Redis types directly to Ruby objects
# https://github.com/nateware/redis-objects
gem "redis-objects"

initializer "redis.rb", <<~'CODE'
  # Multiple Valkey/Redis instances for different purposes
  # This template uses Valkey by default (fully compatible with Redis)
  #
  # redis_cache:   Rails.cache, rate limiting (LRU eviction, no persistence)
  # redis_cable:   ActionCable pub/sub (no eviction, no persistence)
  # redis_session: Access tokens, sessions (no eviction, AOF persistence)

  # Helper method to build Valkey/Redis URL with Docker secrets support
  def build_redis_url(host:, port:, db: 0, password_file: nil, password: nil)
    if password_file && File.exist?(password_file)
      pwd = File.read(password_file).strip
    elsif password
      pwd = password
    end

    if pwd.present?
      "redis://:#{pwd}@#{host}:#{port}/#{db}"
    else
      "redis://#{host}:#{port}/#{db}"
    end
  end

  # Pool size should match RAILS_MAX_THREADS for optimal performance
  pool_size = ENV.fetch("RAILS_MAX_THREADS", 16).to_i

  # Valkey Cache (Rails.cache, Rack::Attack, temporary data)
  cache_url = build_redis_url(
    host:          ENV.fetch("REDIS_CACHE_HOST", "localhost"),
    port:          ENV.fetch("REDIS_CACHE_PORT", 6379),
    db:            0,
    password_file: ENV.fetch("REDIS_CACHE_PASSWORD_FILE", nil),
    password:      ENV.fetch("REDIS_CACHE_PASSWORD", nil)
  )

  REDIS_CACHE = ConnectionPool.new(size: pool_size, timeout: 5) do
    Redis.new(url: cache_url, reconnect_attempts: 3, timeout: 1)
  end

  # Valkey Session (Access tokens, user sessions, important state)
  session_url = build_redis_url(
    host:          ENV.fetch("REDIS_SESSION_HOST", "localhost"),
    port:          ENV.fetch("REDIS_SESSION_PORT", 6379),
    db:            0,
    password_file: ENV.fetch("REDIS_SESSION_PASSWORD_FILE", nil),
    password:      ENV.fetch("REDIS_SESSION_PASSWORD", nil)
  )

  REDIS_SESSION = ConnectionPool.new(size: pool_size, timeout: 5) do
    Redis.new(url: session_url, reconnect_attempts: 3, timeout: 1)
  end

  # Configure Rails cache store to use Valkey Cache
  Rails.application.config.cache_store = :redis_cache_store, {
    url:                cache_url,
    reconnect_attempts: 3,
    pool_size:          pool_size,
    pool_timeout:       5,
    error_handler:      lambda { |_method:, _returning:, exception:|
      Rails.logger.error("Valkey cache error: #{exception.class} - #{exception.message}")
    }
  }

  # Usage examples:
  #
  # Rails.cache (automatically uses REDIS_CACHE / Valkey):
  #   Rails.cache.fetch("key") { expensive_operation }
  #
  # Direct access to cache Valkey:
  #   REDIS_CACHE.with { |redis| redis.get("key") }
  #
  # Access tokens/sessions (use REDIS_SESSION / Valkey):
  #   REDIS_SESSION.with { |redis| redis.setex("token:abc", 3600, user_id) }
  #
CODE
