# Rails Application Templates

Rails 8.1 + Ruby 3.4 API templates with production-ready configuration.

## Features

- API-only (PostgreSQL 18, Valkey 8)
- UUIDv7 primary keys
- Server/Worker architecture (Sidekiq)
- Docker configuration with secrets management
- Structured logging (Rails Semantic Logger)
- Complete test setup (RSpec, FactoryBot, Prosopite)
- Security (Rack::Attack, Pundit, JWT, Sentry)
- YJIT enabled

## Architecture

- Framework: Ruby on Rails 8.1 (API mode)
- Database: PostgreSQL 18
- Cache: Valkey (redis_cache) - Ephemeral
- Background Jobs: Sidekiq (redis_queue) - Persistent
- WebSocket: ActionCable with Valkey adapter (redis_cable) - Ephemeral
- Session Storage: Valkey (redis_session) - Persistent

## Usage

```bash
rails new <project_name> --api -d postgresql --skip-test --skip-solid -m rails-app-templates/template/api.rb
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

- **compose.yaml** - Development environment (default) with optional secrets
- **compose.prod.yaml** - Production environment with external secrets
- **compose.test.yaml** - Test environment with minimal services (pg + rails only)

#### Development

```bash
# Copy and configure environment variables
cp .env.example .env
# Edit .env with your configuration

# (Optional) Create secrets for mailer and Cloudflare Tunnel
# Note: PostgreSQL uses trust authentication (no password)
# Note: Redis services run without authentication in development
mkdir -p .secrets
echo "your-smtp-password" > .secrets/mailer_smtp_password
echo "your-cloudflare-tunnel-token" > .secrets/cf_tunnel_token

# Build with host user permissions (for volume mounting)
# Set APP_UID/APP_GID to match host user for proper file permissions
APP_UID=$(id -u) APP_GID=$(id -g) docker compose build

# Start services
docker compose up -d
```

#### Production (Docker Swarm)

Production deployment uses Docker Swarm for orchestration and high availability.

```bash
# Initialize Docker Swarm (if not already initialized)
docker swarm init

# Create Docker secrets
echo "your-secret" | docker secret create rails_app_pg_password -
echo "your-secret" | docker secret create rails_app_redis_cache_password -
echo "your-secret" | docker secret create rails_app_redis_cable_password -
echo "your-secret" | docker secret create rails_app_redis_session_password -
echo "your-secret" | docker secret create rails_app_redis_queue_password -
echo "your-secret" | docker secret create rails_app_rails_secret_key_base -
echo "your-secret" | docker secret create rails_app_mailer_smtp_password -
echo "your-secret" | docker secret create rails_app_cf_tunnel_token -

# Configure environment variables
cp .env.example .env.prod
# Edit .env.prod with your production configuration

# Build and deploy to Docker Stack
bin/deploy build           # Build Docker image
bin/deploy up              # Deploy stack

# Or build and deploy in one command
bin/deploy up --build

# Manage deployment
bin/deploy status          # Check service status
bin/deploy logs server     # View server logs
bin/deploy logs worker     # View worker logs
bin/deploy restart         # Restart all services
bin/deploy restart server  # Restart specific service
bin/deploy down            # Remove stack
```

**Environment Variables:**

- `APP_STACK_NAME` - Stack name (default: rails-app)
- `APP_IMAGE_NAME` - Image name (default: local/rails-app:REVISION)

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
- **rails_semantic_logger** - Structured JSON logging
- **pg** - PostgreSQL adapter
- **sidekiq** - Background job processing

### API Development

- **alba** - Fast JSON serialization
- **rack-attack** - API rate limiting (requires configuration)
- **rack-cors** - CORS support
- **jwt** - JWT authentication
- **pundit** - Authorization
- **active_storage_validations** - Active Storage attachment validations

### Redis

- **redis** - Redis client
- **connection_pool** - Thread-safe connection pooling

### Testing

- **rspec-rails** - RSpec framework
- **factory_bot_rails** - Test data factories
- **faker** - Generate fake data
- **shoulda-matchers** - RSpec matchers
- **prosopite** - N+1 query detection

### Development

- **debug** - Ruby's official debugger
- **rubocop** - Ruby code analyzer
- **erb_lint** - ERB template linter
- **brakeman** - Rails security vulnerability scanner (Rails built-in)
- **benchmark-ips** - Performance benchmarking
- **pg_query** - PostgreSQL query parser

### Monitoring

- **sentry-ruby** / **sentry-rails** - Error tracking (production only)
