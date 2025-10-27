# Create optimized Puma configuration for production
create_file "config/puma.rb", <<~RUBY, force: true
  # Puma can serve each request in a thread from an internal thread pool.
  # The `threads` method setting takes two numbers: a minimum and maximum.
  # Any libraries that use thread pools should be configured to match
  # the maximum value specified for Puma. Default is set to 5 threads for minimum
  # and maximum; this matches the default thread size of Active Record.
  #
  max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 16).to_i
  min_threads_count = ENV.fetch("RAILS_MIN_THREADS", max_threads_count).to_i
  threads min_threads_count, max_threads_count

  # Specifies the `worker_timeout` as a number of seconds. If you have long-running jobs,
  # you may need to increase this value. Default is 30 seconds.
  #
  worker_timeout ENV.fetch("PUMA_WORKER_TIMEOUT") { 30 }

  # Specifies the `bind` address that Puma will listen on.
  # Default is 0.0.0.0 to allow access from any interface (required for Docker containers).
  # Use BIND env var to override (e.g., BIND="tcp://127.0.0.1:3000" for localhost only)
  #
  bind ENV.fetch("BIND") { "tcp://0.0.0.0:\#{ENV.fetch('PORT', 3000)}" }

  # Specifies the `environment` that Puma will run in.
  #
  environment ENV.fetch("RAILS_ENV") { "development" }

  # Specifies the `pidfile` that Puma will use.
  pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

  # Specifies the number of `workers` to boot in clustered mode.
  # Workers are forked web server processes. If using threads and workers together
  # the concurrency of the application would be max `threads` * `workers`.
  # Workers do not work on JRuby or Windows (both of which do not support
  # processes).
  #
  # In production, you typically want to set this to the number of available CPU cores.
  # Default: 0 (single mode, no workers)
  workers ENV.fetch("WEB_CONCURRENCY") { 0 }

  # Use the `preload_app!` method when specifying a `workers` number.
  # This directive tells Puma to first boot the application and load code
  # before forking the application. This takes advantage of Copy On Write
  # process behavior so workers use less memory.
  #
  if ENV.fetch("WEB_CONCURRENCY", 0).to_i > 0
    preload_app!

    # Disconnect from database and external services before forking
    # This prevents socket connections from being copied to child processes
    before_fork do
      # Disconnect ActiveRecord
      ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)

      # Disconnect Redis ConnectionPools
      # ConnectionPool will automatically create new connections in workers
      if defined?(REDIS_CACHE)
        REDIS_CACHE.shutdown { |redis| redis.quit rescue nil }
      end
      if defined?(REDIS_SESSION)
        REDIS_SESSION.shutdown { |redis| redis.quit rescue nil }
      end
    end

    # Reconnect to database and external services after forking
    # Each worker process needs its own connections
    on_worker_boot do
      # Reconnect ActiveRecord
      ActiveRecord::Base.establish_connection if defined?(ActiveRecord)

      # Redis ConnectionPools will automatically create new connections
      # when needed, so no explicit reconnection is required.
      # However, you can test the connection if needed:
      # REDIS_CACHE.with { |redis| redis.ping } if defined?(REDIS_CACHE)
    end
  end

  # Allow puma to be restarted by `rails restart` command.
  plugin :tmp_restart
RUBY
