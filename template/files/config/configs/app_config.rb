# Application configuration using anyway_config
# Loads configuration from environment variables with APP_ prefix
# Usage: AppConfig.instance.postgres_host
class AppConfig < Anyway::Config
  config_name :app

  # Singleton pattern for performance and memory efficiency
  # Ensures only one instance is created throughout the application lifecycle
  def self.instance
    @instance ||= new
  end

  # Database Configuration
  attr_config :postgres_host,
              :postgres_port,
              :postgres_db,
              :postgres_user,
              :postgres_password_file,
              :rails_db_prepare

  # Redis Cache Configuration
  attr_config :redis_cache_host,
              :redis_cache_port,
              :redis_cache_password_file

  # Redis Session Configuration
  attr_config :redis_session_host,
              :redis_session_port,
              :redis_session_password_file

  # Redis Cable Configuration
  attr_config :redis_cable_host,
              :redis_cable_port,
              :redis_cable_password_file

  # Rails Core Configuration
  attr_config :time_zone,
              :allowed_hosts,
              :cors_allowed_origins,
              :secret_key_base_file

  # Puma Web Server Configuration
  attr_config :web_concurrency,
              :rails_max_threads,
              :rails_min_threads,
              :puma_worker_timeout

  # Mailer Configuration
  attr_config :mailer_smtp_address,
              :mailer_smtp_port,
              :mailer_smtp_domain,
              :mailer_smtp_authentication,
              :mailer_smtp_enable_starttls_auto,
              :mailer_smtp_user_name,
              :mailer_smtp_password_file,
              :admin_email,
              :mailer_server_host,
              :mailer_server_port,
              :mailer_server_protocol

  # ActionCable Configuration
  attr_config :action_cable_url,
              :action_cable_allowed_origins,
              :action_cable_disable_forgery_protection

  # Email Verification Configuration
  attr_config :email_verification_code_lifetime,
              :email_verification_registrable_lifetime,
              :email_verification_resend_cooldown

  # Session Configuration
  attr_config :session_key,
              :session_expire_after,
              :session_cookie_secure,
              :session_cookie_domain,
              :session_cookie_same_site,
              :session_access_token_lifetime,
              :session_refresh_token_lifetime

  # Background Jobs Configuration
  attr_config :job_concurrency

  # Logging Configuration
  attr_config :rails_log_level

  # Monitoring & Error Tracking
  attr_config :sentry_dsn,
              :sentry_environment,
              :sentry_traces_sample_rate

  # Type coercions - automatically convert environment variables to correct types
  coerce_types postgres_port:                           :integer,
               rails_db_prepare:                        :boolean,
               redis_cache_port:                        :integer,
               redis_session_port:                      :integer,
               redis_cable_port:                        :integer,
               allowed_hosts:                           { type: :string, array: true },
               cors_allowed_origins:                    { type: :string, array: true },
               email_verification_code_lifetime:        :integer,
               email_verification_registrable_lifetime: :integer,
               email_verification_resend_cooldown:      :integer,
               web_concurrency:                         :integer,
               rails_max_threads:                       :integer,
               rails_min_threads:                       :integer,
               puma_worker_timeout:                     :integer,
               mailer_smtp_port:                        :integer,
               mailer_server_port:                      :integer,
               mailer_smtp_enable_starttls_auto:        :boolean,
               mailer_smtp_authentication:              ->(val) { val.to_s.to_sym },
               action_cable_disable_forgery_protection: :boolean,
               action_cable_allowed_origins:            { type: :string, array: true },
               session_expire_after:                    :integer,
               session_cookie_secure:                   :boolean,
               session_cookie_same_site:                ->(val) { val.to_s.to_sym },
               session_access_token_lifetime:           :integer,
               session_refresh_token_lifetime:          :integer,
               job_concurrency:                         :integer,
               sentry_traces_sample_rate:               :float

  # Provide fallback defaults when environment variables are not set
  # In Docker: env_file loads .env and these values are overridden
  # In template: these defaults ensure initialization succeeds
  def time_zone
    super || "UTC"
  end

  def cors_allowed_origins
    super || ["*"]
  end

  def web_concurrency
    super || 0
  end

  def rails_max_threads
    super || 5
  end

  def rails_min_threads
    super || 5
  end

  def puma_worker_timeout
    super || 30
  end

  # File reader helper methods
  def postgres_password
    read_file(postgres_password_file)
  end

  def redis_cache_password
    read_file(redis_cache_password_file)
  end

  def redis_session_password
    read_file(redis_session_password_file)
  end

  def redis_cable_password
    read_file(redis_cable_password_file)
  end

  def mailer_smtp_password
    read_file(mailer_smtp_password_file)
  end

  def secret_key_base
    read_file(secret_key_base_file)
  end

  private

  # Read file content and return empty string if file not found
  def read_file(file_path)
    return "" if file_path.blank?

    File.read(file_path).strip
  rescue Errno::ENOENT
    ""
  end
end
