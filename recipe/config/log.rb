# Logging Configuration
#
# This template uses Lograge for structured JSON logging in production
# https://github.com/roidrage/lograge
#
# Production: Single-line JSON logs (easy for ELK, Datadog, CloudWatch)
# Development: Human-readable colorized logs
# Test: Minimal logs (warn level)
#
# Note: Rails 8.1+ automatically silences /up health check requests by default
# (config.silence_healthcheck_path = "/up" is already configured in production.rb)

# Production environment: Structured JSON logs with Lograge
environment <<~RUBY, env: "production"
  # Enable Lograge for structured single-line logs
  config.lograge.enabled = true

  # Use JSON formatter (easy parsing for log aggregation tools)
  config.lograge.formatter = Lograge::Formatters::Json.new

  # API-only app configuration
  config.lograge.base_controller_class = 'ActionController::API'

  # Add custom fields to each log entry
  config.lograge.custom_options = lambda do |event|
    {
      request_id: event.payload[:request_id],
      user_id: event.payload[:user_id],
      ip: event.payload[:ip]
    }
  end

  # Log to STDOUT for Docker container (captured by Docker logs)
  config.logger = ActiveSupport::Logger.new(STDOUT)

  # Set log level (can be overridden by LOG_LEVEL env var)
  config.log_level = ENV.fetch("LOG_LEVEL", "info").to_sym
RUBY

# Development environment: Human-readable logs
environment <<~RUBY, env: "development"
  # Colorized logs for better readability
  config.colorize_logging = true

  # Show detailed logs in development
  config.log_level = :debug
RUBY

# Test environment: Minimal logs
environment <<~RUBY, env: "test"
  # Reduce noise in test output
  config.log_level = :warn
RUBY
