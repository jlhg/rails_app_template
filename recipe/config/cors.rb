# CORS Configuration Initializer
# Rails 8.1+ creates a commented-out cors.rb by default in API mode
# Remove it first to avoid conflict

gem "rack-cors"

remove_file "config/initializers/cors.rb"

initializer "cors.rb", <<~CODE
  # CORS (Cross-Origin Resource Sharing) Configuration
  #
  # Configure which domains can make cross-origin requests to your API
  # Use CORS_ALLOWED_ORIGINS environment variable (comma-separated list)
  #
  # Examples:
  # - Development: CORS_ALLOWED_ORIGINS=* (allow all, credentials disabled)
  # - Production: CORS_ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com
  #   (specific origins, credentials enabled)
  #
  # IMPORTANT: Use insert_before 0 to ensure Rack::Cors runs first
  # This prevents conflicts with other middleware (Warden, Rack::Cache, etc.)
  # Reference: https://github.com/cyu/rack-cors#rails-configuration
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins_list = AppConfig.instance.cors_allowed_origins

      # Parse origins and determine credentials setting
      if origins_list == ["*"]
        origins "*"
        use_credentials = false
      else
        origins(*origins_list) unless origins_list.empty?
        use_credentials = true
      end

      # ActionCable WebSocket endpoint
      resource "/api/cable",
               headers:     :any,
               methods:     [:get, :post, :options],
               credentials: use_credentials

      # Allow all API resources
      resource "/api/*",
               headers:     :any,
               methods:     [:get, :post, :put, :patch, :delete, :options, :head],
               credentials: use_credentials,
               max_age:     86400 # Cache preflight requests for 24 hours
    end
  end
CODE
