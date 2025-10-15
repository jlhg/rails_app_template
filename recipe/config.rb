# Configuration Management
#
# This template uses three configuration systems:
# 1. ENV variables (.env)        - Environment configuration (host, port, database, threads, CORS)
# 2. Docker Secrets (.secrets/)  - Sensitive data (passwords, API keys, tokens)
# 3. Settings (settings.yml)     - Business logic (timeout, limits, rules, feature flags)
#
# Examples of business logic configuration (use Settings):
# - Token expiration times: Settings.access_token_expired_time
# - Business limits: Settings.max_upload_size, Settings.max_retry_times
# - Feature flags: Settings.enable_chatgpt, Settings.enable_sentry
# - Business rules: Settings.allowed_ip_addresses, Settings.default_avatar_url
# - Timeout settings: Settings.job_timeout, Settings.api_timeout
#
# Note: config gem is installed but settings.yml only stores pg_db_prefix by default.
# Add your business logic configuration as needed.

init_gem "config"
init_gem "rack-cors"
init_gem "lograge"

recipe "config/time_zone"
recipe "config/cors"
recipe "config/pg"
recipe "config/puma"
recipe "config/action_mailer"
recipe "config/log"
