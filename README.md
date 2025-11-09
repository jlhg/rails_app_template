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

## Configuration

### Environment Variables

All application configuration uses the `APP_` prefix for environment variables. See `.env.example` for the complete list of available settings.

Key configuration areas:
- Database (PostgreSQL)
- Redis (Cache, Cable, Session)
- Rails settings (timezone, allowed hosts, CORS)
- Puma web server
- Mailer (SMTP)
- ActionCable (WebSocket)
- Session management
- Monitoring (Sentry)

### AppConfig

Configuration is managed through `AppConfig.instance` (using the `anyway_config` gem):

```ruby
# Access configuration
AppConfig.instance.postgres_host
AppConfig.instance.redis_cache_host
AppConfig.instance.rails_max_threads

# Read secrets from Docker secret files
AppConfig.instance.postgres_password
AppConfig.instance.redis_cache_password
```

### Docker Compose Files

Three separate compose files for different environments:

- **compose.yaml** - Production environment with external secrets
- **compose.dev.yaml** - Development environment with file secrets and volume mounts
- **compose.test.yaml** - Test environment with minimal services (pg + rails only)

#### Development

```bash
# Create secrets directory
mkdir -p .secrets

# Generate secrets (example)
openssl rand -hex 64 > .secrets/database_password
openssl rand -hex 64 > .secrets/redis_cache_password
openssl rand -hex 64 > .secrets/redis_cable_password
openssl rand -hex 64 > .secrets/redis_session_password
openssl rand -hex 64 > .secrets/rails_secret_key_base
echo "your-smtp-password" > .secrets/mailer_smtp_password
echo "your-cloudflare-tunnel-token" > .secrets/cf_tunnel_token

# Copy and configure environment variables
cp .env.example .env
# Edit .env with your configuration

# Build with host user permissions (for volume mounting)
# Set APP_UID/APP_GID to match host user for proper file permissions
APP_UID=$(id -u) APP_GID=$(id -g) docker compose -f compose.dev.yaml build

# Start services
docker compose -f compose.dev.yaml up -d
```

#### Production

```bash
# Create Docker secrets
echo "your-secret" | docker secret create rails_app_database_password -
echo "your-secret" | docker secret create rails_app_redis_cache_password -
echo "your-secret" | docker secret create rails_app_redis_cable_password -
echo "your-secret" | docker secret create rails_app_redis_session_password -
echo "your-secret" | docker secret create rails_app_rails_secret_key_base -
echo "your-secret" | docker secret create rails_app_mailer_smtp_password -
echo "your-secret" | docker secret create rails_app_cf_tunnel_token -

# Build and deploy
REVISION=$(git rev-parse --short HEAD) docker compose build
docker compose up -d
```

#### Testing

```bash
# Run tests
docker compose -f compose.test.yaml run --rm rails bundle exec rspec
```

## Included Gems

### Core
- **bcrypt** - Password encryption
- **anyway_config** - Configuration management with ENV support
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
