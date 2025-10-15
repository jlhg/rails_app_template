environment <<~CODE
  # IMPORTANT: Use insert_before 0 to ensure Rack::Cors runs first
  # This prevents conflicts with other middleware (Warden, Rack::Cache, etc.)
  # Reference: https://github.com/cyu/rack-cors#rails-configuration
  config.middleware.insert_before 0, Rack::Cors do
    allow do
      # CORS origins from ENV (comma-separated list)
      # Development: CORS_ORIGINS=*
      # Production: CORS_ORIGINS=https://app.example.com,https://admin.example.com
      origins ENV.fetch('CORS_ORIGINS', '*').split(',').map(&:strip)
      resource "*",
               headers: :any,
               expose: ["access-token", "expiry", "token-type", "uid", "client"],
               methods: [:get, :post, :patch, :put, :delete, :options]
    end
  end
CODE
