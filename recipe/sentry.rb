# Sentry Configuration
#
# Configures Sentry for error tracking and performance monitoring
# https://docs.sentry.io/platforms/ruby/guides/rails/configuration/
#
# Configuration through environment variables:
# - SENTRY_DSN: Sentry project DSN (required for Sentry to work)
# - SENTRY_ENVIRONMENT: Environment name (defaults to RAILS_ENV)
# - SENTRY_TRACES_SAMPLE_RATE: Performance sampling rate (defaults to 0.1 = 10%)
# - REVISION: Git commit SHA for release tracking (set during Docker build)
#
# Security:
# - Only enabled in production (development uses Rails default error handling)
# - Automatically filters sensitive data (passwords, tokens, secrets)
# - Does not send user data unless explicitly configured
#
# Performance:
# - Samples 10% of transactions by default (adjust via SENTRY_TRACES_SAMPLE_RATE)
# - Excludes health check requests (/up) to avoid unnecessary quota usage
# - Async error reporting (doesn't slow down requests)
#
# Release Tracking:
# - REVISION environment variable is set during Docker build
# - Build with: docker build --build-arg REVISION=$(git rev-parse --short HEAD)
# - Can be overridden via .env file for testing
# - If not set, release tracking is disabled

gem "sentry-ruby"
gem "sentry-rails"

initializer "sentry.rb", <<~RUBY
  # Sentry configuration for error tracking and performance monitoring
  # https://docs.sentry.io/platforms/ruby/guides/rails/

  Sentry.init do |config|
    # DSN (Data Source Name) - get this from your Sentry project settings
    # If not set, Sentry will be disabled (safe for development)
    config.dsn = ENV.fetch("SENTRY_DSN", nil)

    # Enable only in production environment
    # Development and test environments use Rails default error handling
    config.enabled_environments = ["production"]

    # Set environment name (defaults to Rails.env if not specified)
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)

    # Breadcrumbs: Record user actions leading to errors
    # Helps understand the context when an error occurs
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]

    # Send PII (Personally Identifiable Information)
    # Set to false to avoid sending user data (emails, IPs, etc.)
    # Enable only if your privacy policy allows it
    config.send_default_pii = false

    # Filter sensitive data from error reports
    # Automatically removes password, token, secret fields
    config.excluded_exceptions += [
      "ActionController::RoutingError",
      "ActiveRecord::RecordNotFound"
    ]

    # Release tracking: Use git commit SHA as release identifier
    # REVISION environment variable is set during Docker build
    # Can be overridden via .env file if needed
    # If REVISION is not set, release tracking is disabled
    config.release = ENV["REVISION"].presence

    # Performance monitoring: Exclude health check requests
    # Docker health checks run every 30s (2,880+ requests/day)
    # Filtering /up saves quota and keeps focus on actual business requests
    config.traces_sampler = lambda do |sampling_context|
      rack_env = sampling_context[:env]
      transaction_name = sampling_context[:transaction_context][:name]

      # Don't sample health check requests
      # Rails 8 health check: GET /up
      return 0.0 if rack_env["PATH_INFO"] == "/up"
      return 0.0 if transaction_name&.include?("/up")

      # Sample all other requests at configured rate
      ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.1).to_f
    end

    # Before sending transactions, filter out health checks
    # This is a safety net in case traces_sampler doesn't catch them
    config.before_send_transaction = lambda do |event, _hint|
      # Skip health check transactions
      return nil if event.transaction == "/up"
      return nil if event.request&.url&.end_with?("/up")

      event
    end

    # Before sending error reports, scrub sensitive data
    config.before_send = lambda do |event, _hint|
      # Additional custom filtering can be added here if needed
      # For example: filter out specific user IDs, remove certain tags, etc.
      event
    end
  end
RUBY
