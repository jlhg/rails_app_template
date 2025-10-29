# Rack Attack - Rate Limiting and Throttling
# https://github.com/rack/rack-attack
#
# Rack middleware for blocking and throttling abusive requests.
# Essential for API security and DDoS protection.
#
# Features:
# - Rate limiting (requests per time period)
# - Throttling (gradually slow down requests)
# - Blocklists and allowlists (IP addresses, user agents)
# - Custom rules with flexible conditions
#
# Common use cases:
# - Prevent brute-force attacks (login, password reset)
# - API rate limiting (per user, per IP)
# - Block malicious bots and scrapers
# - Prevent excessive signups from same IP
#
# Example configuration:
#   Rack::Attack.throttle("api/ip", limit: 100, period: 1.minute) do |req|
#     req.ip if req.path.start_with?("/api")
#   end
#
# Note: Requires Redis/Valkey for distributed rate limiting (already configured)

gem "rack-attack"

initializer "rack_attack.rb", <<~RUBY
  # Rack Attack Configuration
  # https://github.com/rack/rack-attack
  #
  # Basic rate limiting configuration. Customize based on your needs.

  class Rack::Attack
    # Use Rails.cache for distributed rate limiting across multiple servers
    # Rails.cache is already configured to use Valkey/Redis in production
    # This avoids initializer loading order issues
    Rack::Attack.cache.store = Rails.cache

    # Throttle API requests by IP address
    # Allow 100 requests per minute per IP
    throttle("api/ip", limit: 100, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/api")
    end

    # Throttle login attempts by IP address
    # Allow 5 login attempts per minute per IP
    throttle("auth/ip", limit: 5, period: 1.minute) do |req|
      req.ip if req.path == "/api/auth/login" && req.post?
    end

    # Throttle login attempts by email
    # Allow 5 login attempts per minute per email
    throttle("auth/email", limit: 5, period: 1.minute) do |req|
      if req.path == "/api/auth/login" && req.post?
        # Get email from request body (adjust based on your auth implementation)
        req.params["email"].presence
      end
    end

    # Custom response for throttled requests
    self.throttled_responder = lambda do |env|
      retry_after = (env["rack.attack.match_data"] || {})[:period]
      [
        429,
        {
          "Content-Type"  => "application/json",
          "Retry-After"   => retry_after.to_s
        },
        [{ error: "Rate limit exceeded. Please try again later." }.to_json]
      ]
    end
  end
RUBY
