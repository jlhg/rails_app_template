# Configuration Management
#
# This template uses anyway_config for unified configuration management:
# 1. ENV variables with APP_ prefix  - All application configuration
# 2. Docker Secrets (.secrets/)      - Sensitive data (passwords, API keys, tokens)
#
# All environment variables use APP_ prefix (e.g., APP_POSTGRES_HOST)
# Access configuration via: AppConfig.instance.postgres_host
#
# Examples:
# - Database: AppConfig.instance.postgres_host
# - Redis: AppConfig.instance.redis_cache_host
# - Mailer: AppConfig.instance.mailer_smtp_address
# - Session: AppConfig.instance.session_expire_after
# - Sentry: AppConfig.instance.sentry_dsn
#
# Docker secrets are read via *_file attributes (e.g., postgres_password_file)
# and accessed via helper methods (e.g., postgres_password)

gem "anyway_config", "~> 2.0"

# Create config/configs directory for configuration classes
empty_directory "config/configs"

# Copy AppConfig class
copy_file from_files("config/configs/app_config.rb"), "config/configs/app_config.rb"
