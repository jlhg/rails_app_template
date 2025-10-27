# CORS Configuration Initializer
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
      # Get allowed origins from environment variable
      # Default: "*" (allow all origins)
      # Production: Set explicit origins for security
      # Example: CORS_ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com
      cors_origins = ENV.fetch("CORS_ALLOWED_ORIGINS", "*")

      # Parse origins and determine credentials setting
      if cors_origins == "*"
        origins "*"
        use_credentials = false
      else
        origins_list = cors_origins.split(",").map(&:strip).reject(&:empty?)
        origins(*origins_list) unless origins_list.empty?
        use_credentials = true
      end

      # Allow all API resources
      resource "/api/*",
               headers:     :any,
               methods:     [:get, :post, :put, :patch, :delete, :options, :head],
               credentials: use_credentials, # Only enable with specific origins
               max_age:     86400 # Cache preflight requests for 24 hours

      # ActionCable WebSocket endpoint
      resource "/cable",
               headers:     :any,
               methods:     [:get, :post, :options],
               credentials: use_credentials
    end
  end
CODE
