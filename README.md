# Rails Application Template

Rails 8.1 + Ruby 3.4 API template with production-ready configuration.

## Features

- API-only (PostgreSQL 18, Valkey 8)
- UUIDv7 primary keys
- Docker configuration with secrets management
- Structured logging (Lograge)
- Complete test setup (RSpec, FactoryBot, Prosopite)
- Security (Rack::Attack, Pundit, JWT, Sentry)
- YJIT enabled (15-30% performance boost)

## Usage

```bash
rails new <project_name> --api -d postgresql --skip-test -m rails_app_template/template/api.rb
```

## Included Gems

### Core
- **bcrypt** - Password encryption
- **config** - Multi-environment YAML settings
- **pagy** - Fast pagination
- **aasm** - State machine
- **lograge** - Structured JSON logging

### API Development
- **alba** - Fast JSON serialization
- **oj** - High-performance JSON parser
- **rack-attack** - API rate limiting (requires configuration)
- **rack-cors** - CORS support
- **jwt** - JWT authentication
- **pundit** - Authorization

### Redis
- **redis** - Redis client
- **connection_pool** - Thread-safe connection pooling
- **redis-objects** - Ruby objects backed by Redis

### Testing
- **rspec-rails** - RSpec framework
- **factory_bot_rails** - Test data factories
- **faker** - Generate fake data
- **shoulda-matchers** - RSpec matchers
- **mock_redis** - Mock Redis for testing
- **prosopite** - N+1 query detection

### Development
- **debug** - Ruby's official debugger
- **rubocop** - Ruby code analyzer
- **benchmark-ips** - Performance benchmarking

### Monitoring
- **sentry-ruby** / **sentry-rails** - Error tracking (production only)
