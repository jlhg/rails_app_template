# HTTP Client - Faraday

## Overview

This template **does not include** an HTTP client gem by default because it's an API server template primarily for providing API services.

An HTTP client is only needed when **integrating with third-party APIs**.

## When Do You Need an HTTP Client?

### Scenarios Where It's Needed

- ✅ **Payment Gateway Integration** - Stripe, PayPal, ECPay
- ✅ **SMS/Email Services** - Twilio, SendGrid, Mailgun
- ✅ **Cloud Service APIs** - AWS, Google Cloud, Azure
- ✅ **Social Login** - Facebook, Google, LINE OAuth
- ✅ **Webhook Notifications** - Slack, Discord, Telegram
- ✅ **Microservices Architecture** - Calling other internal services
- ✅ **Web Scraping/Data Fetching** - Periodically fetching external data

### Scenarios Where It's Not Needed

- ❌ **Only Providing REST API** - For frontend to call
- ❌ **Only Handling WebSocket** - ActionCable
- ❌ **Pure Database Operations** - CRUD

## Why Choose Faraday?

Compared to other HTTP client libraries, Faraday's advantages:

| Feature | Faraday | HTTParty | Net::HTTP |
|-----|---------|----------|-----------|
| **Flexibility** | ✅✅✅ Highest | ✅✅ Medium | ✅ Low |
| **Middleware** | ✅ Pluggable | ❌ None | ❌ None |
| **Ease of Use** | ✅✅ Simple | ✅✅✅ Simplest | ❌ Cumbersome |
| **Performance** | ✅✅ Selectable adapter | ✅ Fixed | ✅✅✅ Fastest |
| **Maintenance Status** | ✅✅✅ Active | ✅✅ Active | ✅ Ruby built-in |
| **Ecosystem** | ✅✅✅ Rich | ✅ Medium | ❌ None |

**Reasons to Recommend Faraday**:
1. **Pluggable Architecture** - Can swap underlying HTTP adapter (Net::HTTP, Typhoeus, etc.)
2. **Middleware System** - Easy to add logging, retry, timeout, etc.
3. **Active Maintenance** - Rails community mainstream choice
4. **Rich Middleware** - Community provides many ready-made middleware

## Installation

### 1. Add to Gemfile

```ruby
# Gemfile

# HTTP client for external API integration
gem 'faraday', '~> 2.12'

# Optional middleware
gem 'faraday-retry', '~> 2.2'      # Auto retry
gem 'faraday-multipart', '~> 1.0'  # File uploads
gem 'faraday-follow_redirects'     # Auto follow redirects

# Optional adapters (defaults to Net::HTTP)
# gem 'typhoeus', '~> 1.4'         # Multi-threading support
# gem 'patron', '~> 0.13'          # libcurl wrapper
```

### 2. Install Gems

```bash
bundle install
```

## Basic Usage

### Simple Requests

```ruby
require 'faraday'

# GET request
response = Faraday.get('https://api.example.com/users')
puts response.status  # 200
puts response.body    # JSON string

# POST request
response = Faraday.post('https://api.example.com/users') do |req|
  req.headers['Content-Type'] = 'application/json'
  req.body = { name: 'John', email: 'john@example.com' }.to_json
end
```

### Creating Connection

```ruby
# Create reusable connection
conn = Faraday.new(
  url: 'https://api.example.com',
  headers: {
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{ENV['API_TOKEN']}"
  }
) do |f|
  # Middleware order matters!
  f.request :json                    # Auto convert body to JSON
  f.request :retry, max: 3           # Retry 3 times on failure
  f.response :json                   # Auto parse JSON response
  f.response :raise_error            # Auto throw error on 4xx/5xx
  f.adapter Faraday.default_adapter  # Use Net::HTTP
end

# Using connection
users = conn.get('/users').body
user = conn.post('/users', { name: 'John' }).body
```

## Advanced Usage

### Creating Service Class

```ruby
# app/services/github_service.rb
class GitHubService
  BASE_URL = 'https://api.github.com'

  def initialize(token: nil)
    @token = token || ENV['GITHUB_TOKEN']
  end

  def get_user(username)
    response = connection.get("/users/#{username}")
    response.body
  rescue Faraday::Error => e
    Rails.logger.error("GitHub API error: #{e.message}")
    nil
  end

  def get_repos(username)
    response = connection.get("/users/#{username}/repos")
    response.body
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.request :retry, max: 3, interval: 0.5
      f.response :json
      f.response :raise_error
      f.response :logger, Rails.logger, { headers: true, bodies: true }
      f.headers['Authorization'] = "Bearer #{@token}" if @token
      f.adapter Faraday.default_adapter
    end
  end
end

# Usage
service = GitHubService.new
user = service.get_user('octocat')
repos = service.get_repos('octocat')
```

### Timeout Configuration

```ruby
conn = Faraday.new(url: 'https://api.example.com') do |f|
  f.options.timeout = 5           # Overall timeout (seconds)
  f.options.open_timeout = 2      # Connection timeout (seconds)
  f.adapter Faraday.default_adapter
end
```

### Error Handling

```ruby
begin
  response = conn.get('/users/123')
  user = response.body
rescue Faraday::ConnectionFailed => e
  # Cannot connect to server
  Rails.logger.error("Connection failed: #{e.message}")
rescue Faraday::TimeoutError => e
  # Request timeout
  Rails.logger.error("Request timeout: #{e.message}")
rescue Faraday::UnauthorizedError => e
  # 401 Unauthorized
  Rails.logger.error("Unauthorized: #{e.message}")
rescue Faraday::ClientError => e
  # Other 4xx errors
  Rails.logger.error("Client error: #{e.response[:status]}")
rescue Faraday::ServerError => e
  # 5xx errors
  Rails.logger.error("Server error: #{e.response[:status]}")
rescue Faraday::Error => e
  # Other Faraday errors
  Rails.logger.error("Request failed: #{e.message}")
end
```

## Common Use Cases

### 1. Third-Party OAuth Login

```ruby
# app/services/oauth/google_service.rb
module OAuth
  class GoogleService
    TOKEN_URL = 'https://oauth2.googleapis.com/token'
    USER_INFO_URL = 'https://www.googleapis.com/oauth2/v2/userinfo'

    def exchange_code_for_token(code)
      response = connection.post(TOKEN_URL) do |req|
        req.body = {
          code: code,
          client_id: ENV['GOOGLE_CLIENT_ID'],
          client_secret: ENV['GOOGLE_CLIENT_SECRET'],
          redirect_uri: ENV['GOOGLE_REDIRECT_URI'],
          grant_type: 'authorization_code'
        }
      end

      response.body['access_token']
    end

    def get_user_info(access_token)
      response = connection.get(USER_INFO_URL) do |req|
        req.headers['Authorization'] = "Bearer #{access_token}"
      end

      response.body
    end

    private

    def connection
      @connection ||= Faraday.new do |f|
        f.request :json
        f.response :json
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end
  end
end
```

### 2. Webhook Notifications

```ruby
# app/services/slack_notifier.rb
class SlackNotifier
  def initialize(webhook_url: ENV['SLACK_WEBHOOK_URL'])
    @webhook_url = webhook_url
  end

  def notify(message, channel: nil)
    payload = { text: message }
    payload[:channel] = channel if channel

    connection.post(@webhook_url, payload)
  rescue Faraday::Error => e
    Rails.logger.error("Slack notification failed: #{e.message}")
  end

  def notify_deployment(app_name, version, environment)
    message = ":rocket: *#{app_name}* v#{version} deployed to *#{environment}*"
    notify(message)
  end

  private

  def connection
    @connection ||= Faraday.new do |f|
      f.request :json
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end
  end
end

# Usage
SlackNotifier.new.notify_deployment('My App', '1.2.3', 'production')
```

### 3. Payment Gateway Integration (Stripe Example)

```ruby
# app/services/payment/stripe_service.rb
module Payment
  class StripeService
    BASE_URL = 'https://api.stripe.com/v1'

    def initialize(api_key: ENV['STRIPE_SECRET_KEY'])
      @api_key = api_key
    end

    def create_payment_intent(amount:, currency: 'twd')
      response = connection.post('/payment_intents') do |req|
        req.body = {
          amount: amount,
          currency: currency
        }
      end

      response.body
    end

    def retrieve_payment_intent(payment_intent_id)
      response = connection.get("/payment_intents/#{payment_intent_id}")
      response.body
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :url_encoded  # Stripe uses form encoding
        f.response :json
        f.response :raise_error
        f.headers['Authorization'] = "Bearer #{@api_key}"
        f.adapter Faraday.default_adapter
      end
    end
  end
end
```

### 4. Microservice Communication

```ruby
# app/services/internal/user_service.rb
module Internal
  class UserService
    BASE_URL = ENV['USER_SERVICE_URL'] || 'http://user-service:3000'

    def find_user(user_id)
      response = connection.get("/api/users/#{user_id}")
      response.body
    rescue Faraday::ResourceNotFound
      nil
    end

    def update_user(user_id, attributes)
      response = connection.patch("/api/users/#{user_id}", attributes)
      response.body
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.request :retry, max: 3, interval: 0.5
        f.response :json
        f.response :raise_error
        # Internal services use longer timeout
        f.options.timeout = 10
        f.adapter Faraday.default_adapter
      end
    end
  end
end
```

## Testing

### RSpec Stubbing

```ruby
# spec/services/github_service_spec.rb
RSpec.describe GitHubService do
  describe '#get_user' do
    let(:service) { described_class.new }
    let(:username) { 'octocat' }
    let(:user_data) { { 'login' => 'octocat', 'name' => 'The Octocat' } }

    before do
      stub_request(:get, "https://api.github.com/users/#{username}")
        .to_return(
          status: 200,
          body: user_data.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns user data' do
      result = service.get_user(username)
      expect(result['login']).to eq('octocat')
      expect(result['name']).to eq('The Octocat')
    end
  end

  describe 'error handling' do
    let(:service) { described_class.new }

    it 'handles connection failures' do
      stub_request(:get, "https://api.github.com/users/test")
        .to_raise(Faraday::ConnectionFailed.new('Connection refused'))

      expect(service.get_user('test')).to be_nil
    end
  end
end
```

## Recommended Middleware List

### Official Middleware

```ruby
# Request middleware
f.request :json                    # Auto convert body to JSON
f.request :url_encoded             # Form encoding (default)
f.request :multipart               # File uploads
f.request :retry, max: 3           # Retry on failure
f.request :authorization, 'Bearer', token  # Authorization header

# Response middleware
f.response :json                   # Parse JSON
f.response :xml                    # Parse XML
f.response :raise_error            # Throw error on 4xx/5xx
f.response :follow_redirects       # Auto follow redirects
f.response :logger, Rails.logger   # Log requests/responses
```

### Third-Party Middleware

```ruby
# Gemfile
gem 'faraday-http-cache'        # HTTP caching
gem 'faraday-cookie_jar'        # Cookie management
gem 'faraday-detailed_logger'   # Detailed logging
```

## Performance Optimization

### Using Faster Adapter

```ruby
# Gemfile
gem 'typhoeus'  # Based on libcurl, supports parallel requests

# Usage
conn = Faraday.new do |f|
  f.adapter :typhoeus
end
```

### Connection Pool

```ruby
# Use connection pool to avoid repeatedly creating connections
class ApiClient
  class << self
    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        # ... middleware setup
      end
    end
  end
end
```

## Security Considerations

### 1. Don't Hardcode API Keys

```ruby
# ❌ Don't do this
API_KEY = 'sk_test_1234567890'

# ✅ Use environment variables
API_KEY = ENV['STRIPE_API_KEY']

# ✅ Use Rails credentials
API_KEY = Rails.application.credentials.stripe[:api_key]
```

### 2. Set Reasonable Timeouts

```ruby
# Avoid waiting indefinitely
f.options.timeout = 5           # 5 seconds
f.options.open_timeout = 2      # Connection 2 seconds
```

### 3. Use SSL Verification

```ruby
conn = Faraday.new(url: 'https://api.example.com') do |f|
  # Ensure SSL verification is enabled (default is on)
  f.ssl.verify = true
  f.adapter Faraday.default_adapter
end
```

### 4. Don't Log Sensitive Information

```ruby
# When using logger middleware, avoid logging sensitive info
f.response :logger, Rails.logger do |logger|
  logger.filter(/(Authorization:\s+)(.*)/, '\1[FILTERED]')
end
```

## References

- [Faraday Official Documentation](https://lostisland.github.io/faraday/)
- [Faraday GitHub](https://github.com/lostisland/faraday)
- [Awesome Faraday](https://github.com/lostisland/awesome-faraday) - Middleware List
