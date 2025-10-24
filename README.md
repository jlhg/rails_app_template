# Rails application template

This repo contains templates for new and existing projects optimized for **Rails 8** and **Ruby 3.4**.

The templates are designed for **API-only backend development** with PostgreSQL, focusing on modern API patterns and best practices.

See official documentation [Rails Application Templates](https://guides.rubyonrails.org/rails_application_templates.html) for building a template.

## Usage

### Create API backend project (using PostgreSQL)

Run `rails new` command to create a new project:

```bash
rails new <project_name> --api -d postgresql --skip-test -m template/api.rb
```

### Configuration

This template uses three configuration systems:

1. **ENV variables** (`.env`) - Environment configuration
   ```bash
   # Copy example file for local development
   cp .env.local.example .env

   # Edit database, Redis, CORS, etc.
   nano .env
   ```

2. **Docker Secrets** (`.secrets/`) - Sensitive data
   ```bash
   # See Docker Deployment section for setup
   ```

3. **Settings** (`config/settings.yml`) - Business logic
   ```yaml
   # Add your business configuration as needed
   # Examples: timeout values, limits, rules, feature flags
   ```

### Run DB migration

```bash
bundle exec rake db:migrate db:test:prepare
```

## Included Gems

### Core
- **bcrypt** - Password encryption
- **config** - Multi-environment YAML settings
- **pagy** - Fast pagination with overflow handling
- **aasm** - State machine
- **lograge** - Structured JSON logging for production (single-line logs)

### API Development
- **alba** - Fast, flexible JSON serialization (Ruby 3.4+ optimized)
- **oj** - High-performance JSON parser (optional Alba backend)
- **rack-attack** - API rate limiting and throttling (no default config - see docs)
- **rack-cors** - CORS support
- **jwt** - JWT authentication
- **pundit** - Authorization

### Redis
- **redis** - Redis client
- **connection_pool** - Thread-safe connection pooling
- **redis-objects** - Ruby objects backed by Redis

### Testing
- **rspec-rails** - RSpec testing framework
- **factory_bot_rails** - Test data factories
- **faker** - Generate realistic fake data for tests (names, emails, etc.)
- **shoulda-matchers** - RSpec matchers
- **mock_redis** - Mock Redis for testing (fully compatible with redis-rb)
- **prosopite** - N+1 query detection in tests (zero false positives)

### Development
- **debug** - Ruby's official debugger (Ruby 3.1+)
- **rubocop** - Ruby code analyzer
- **benchmark-ips** - Performance benchmarking

### Monitoring
- **sentry-ruby** / **sentry-rails** - Error tracking and performance monitoring (production only)

## Rails 8 & Ruby 3.4 Optimizations

- **No Spring**: Rails 8 removed Spring in favor of native optimizations
- **Transactional Fixtures**: Uses Rails built-in transactional fixtures instead of database_cleaner
- **Time Helpers**: Uses Rails built-in time helpers (`travel_to`, `freeze_time`) instead of timecop
- **Updated RuboCop**: Fixed deprecated cop names for modern Ruby standards
- **YJIT Enabled**: Ruby 3.4 YJIT provides 15-30% performance improvement
- **Frozen String Literals**: Memory optimization with `--enable-frozen-string-literal`
- **UUIDv7 Primary Keys**: PostgreSQL 18 native UUIDv7 for secure, time-ordered IDs with bigint-level performance (see [docs/ID_STRATEGY.md](docs/ID_STRATEGY.md))

## Testing Enhancements

- **BCrypt Performance**: Test environment uses lower cost factor (3) for 10x faster tests
- **ActiveJob Helpers**: Built-in support for testing background jobs with `:inline_jobs` tag
- **Seed Data Loading**: Automatic loading of `db/seeds.rb` in test suite
- **Storage Host Mocking**: Pre-configured ActiveStorage URL generation for tests
- **Deprecation Tracking**: Automatic detection and reporting of Ruby/Rails deprecation warnings during tests (see [docs/DEPRECATION_TRACKING.md](docs/DEPRECATION_TRACKING.md))

## Docker Deployment

This template includes production-ready Docker configuration with **industry best practices**.

### Development vs Production Images

**Production image (default):**
- Only installs production gems (`BUNDLE_WITHOUT=development:test`)
- Optimized for production use (`RAILS_ENV=production`)
- Smaller image size, faster deployments

**Development image (with all gems):**
```bash
# 1. Copy example file
cp compose.local.yaml.example compose.local.yaml

# 2. Build and run with development configuration
docker compose -f compose.yaml -f compose.local.yaml up --build

# 3. Run tests inside container
docker compose -f compose.yaml -f compose.local.yaml run --rm web bundle exec rspec

# 4. Open Rails console
docker compose -f compose.yaml -f compose.local.yaml exec web bundle exec rails console
```

**Key differences in `compose.local.yaml`:**
- `BUNDLE_WITHOUT: ""` - Installs **all** gems (development + test + production)
- `RAILS_ENV=development` - Development mode
- `volumes: - .:/app` - Live code reload (changes reflected immediately)
- Exposes database/Redis ports for debugging tools

### Structured Logging (Lograge)

This template uses **Lograge** for structured, single-line JSON logs in production, making it easy to parse and analyze with tools like ELK Stack, Datadog, or CloudWatch.

**Production logs (Lograge JSON format):**
```json
{"method":"GET","path":"/api/users","format":"json","controller":"Api::UsersController","action":"index","status":200,"duration":45.67,"view":12.34,"db":23.45,"request_id":"abc123","user_id":456,"ip":"172.18.0.1"}
```

**Development logs (Rails default format):**
```
Started GET "/api/users" for 127.0.0.1 at 2025-01-15 10:00:00
Processing by Api::UsersController#index as JSON
  User Load (1.2ms)  SELECT "users".* FROM "users"
Completed 200 OK in 45ms (Views: 12.3ms | ActiveRecord: 23.4ms)
```

**Key features:**
- ✅ Single-line JSON logs (production only)
- ✅ Includes `request_id`, `user_id`, `ip` for tracing
- ✅ Health check requests (`/up`) automatically silenced
- ✅ Human-readable colorized logs in development
- ✅ Configurable log level via `LOG_LEVEL` environment variable (default: `info`)
- ✅ Output to STDOUT (Docker captures and manages logs)

**Health check silencing:**

Docker health checks (every 30s = 2,880+ entries/day) are automatically silenced in production:

```ruby
# config/environments/production.rb
config.silence_healthcheck_path = "/up"
```

This prevents `/up` requests from flooding your logs with noise, keeping focus on actual business requests.

### Error Tracking & Performance Monitoring (Sentry)

This template includes **Sentry** for real-time error tracking and performance monitoring in production.

**Key Features:**
- ✅ Automatic exception capture with detailed stack traces
- ✅ Performance monitoring (APM) for API endpoints, database queries, external requests
- ✅ Release tracking (correlate errors with deployments)
- ✅ Smart alerting and notifications
- ✅ Breadcrumbs (action trail leading to errors)
- ✅ Issue trends and analytics

**Configuration:**
```bash
# 1. Create Sentry account and project at https://sentry.io
# 2. Set SENTRY_DSN environment variable
export SENTRY_DSN=https://your-key@o123456.ingest.sentry.io/123456

# 3. Build Docker image with git commit SHA for release tracking
REVISION=$(git rev-parse --short HEAD) docker compose build
```

**Automatic Features:**
- Only enabled in production (development uses Rails default error pages)
- 10% performance sampling (configurable via `SENTRY_TRACES_SAMPLE_RATE`)
- Automatic sensitive data filtering (passwords, tokens, secrets)
- Health check filtering (`/up` excluded to save quota)
- Release tracking via `REVISION` environment variable

**Free Tier:**
- 5,000 errors/month
- 10,000 performance transactions/month
- 30-day data retention
- Perfect for small to medium projects

**Error Report Example:**
```
NoMethodError: undefined method `name' for nil:NilClass
- Stack trace with source code context
- Request: POST /api/users
- User: user_id=123, ip=1.2.3.4
- Environment: production, release=abc123
- Breadcrumbs: [login, navigate, click button, error]
```

**Performance Insight Example:**
```
/api/users#index
- P95 response time: 450ms
- Database queries: 8 queries (120ms)
- External API calls: 1 call (200ms)
- Memory allocation: 15MB
```

**Why Sentry?**

While **Lograge** handles structured logging, **Sentry** specializes in error tracking and performance monitoring:

| Feature | Lograge | Sentry |
|---------|---------|--------|
| **Purpose** | Structured logs | Error tracking + APM |
| **Use Case** | General logging | Exception monitoring |
| **Stack Traces** | No | Yes, with source context |
| **Alerting** | No | Yes, real-time alerts |
| **Performance** | Request duration only | Full APM with query details |
| **Trends** | No | Yes, error trends & analytics |
| **Search** | Requires log aggregator | Built-in search |

**Best Practice:** Use both tools together:
- **Lograge** → Daily logs, debugging, audit trail
- **Sentry** → Critical errors, performance issues, alerting

### Included Files
- **compose.yaml** - Docker Compose for production with PostgreSQL 18, Valkey 8, Rails, and Cloudflare Tunnel
- **compose.local.yaml.example** - Development override (includes dev/test gems, live reload)
- **Dockerfile** - Optimized build for Ruby 3.4 + Alpine (supports `BUNDLE_WITHOUT` build arg)
- **docker-entrypoint.sh** - Entrypoint script for initialization and secret handling
- **lib/tasks/docker.rake** - Docker Compose management tasks (build, up, down, logs, console, etc.)
- **.dockerignore** - Reduces image size by excluding unnecessary files
- **.secrets/** - Directory for storing sensitive data (gitignored)
- **.env.example** - Application configuration (deployment-agnostic)
- **.env.local.example** - Local development configuration (non-Docker)

### Architecture Improvements

**Before (naive approach):**
```yaml
command: bash -c '
  export SECRET_KEY_BASE=$$(cat /run/secrets/...)
  export DATABASE_URL=postgresql://...
  bundle exec rails db:prepare
  bundle exec rails s
'
```

**After (best practices):**
```dockerfile
# Dockerfile
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["bundle", "exec", "rails", "server"]
```

```yaml
# compose.yaml - Clean and declarative
environment:
  - DATABASE_HOST=pg
  - DATABASE_USER=postgres
# Secrets handled automatically by entrypoint + Rails config
```

**Key Improvements:**
| Aspect | Before | After |
|--------|--------|-------|
| **Secrets exposure** | Environment variables | Direct file reads + minimal ENV |
| **Maintainability** | Bash script in YAML | Dedicated entrypoint.sh |
| **Reusability** | Web service only | Works for console, worker, etc |
| **Signal handling** | Poor (bash wrapper) | Proper (exec) |
| **Startup control** | Always runs migrations | Configurable via RAILS_DB_PREPARE |
| **Configuration** | Hardcoded URLs | Flexible (URL or components) |

### Docker Management with Rake Tasks

This template includes **`lib/tasks/docker.rake`** for convenient Docker Compose management:

```bash
# Initial setup (create secrets automatically)
rake docker:setup

# Build and start (production-like environment)
rake docker:build
rake docker:up

# Build and start (local development environment)
rake docker:build[local]
rake docker:up[local]

# Common tasks
rake docker:logs          # View logs
rake docker:console       # Rails console
rake docker:shell         # Bash shell
rake docker:migrate       # Run migrations
rake docker:down          # Stop containers

# Database tasks
rake docker:db:prepare    # First time setup
rake docker:db:reset      # Reset database

# Testing (local environment)
rake docker:test:rspec[local]
rake docker:test:rubocop[local]

# See all available tasks
rake docker:help
```

### Quick Start (Manual)

```bash
# 1. Setup secrets (REQUIRED for security)
cd .secrets
for file in *.example; do cp "$file" "${file%.example}"; done

# Generate secure passwords
openssl rand -base64 32 > database_password
openssl rand -base64 32 > redis_cache_password
openssl rand -base64 32 > redis_cable_password
openssl rand -base64 32 > redis_session_password
cd ..
rails secret > .secrets/rails_secret_key_base

# Set proper permissions (REQUIRED for Docker Compose)
chmod 700 .secrets
chmod 640 .secrets/*_password .secrets/*_base

# 2. First deployment (create database)
RAILS_DB_PREPARE=true docker compose up -d

# 3. Wait for services to be healthy
docker compose ps

# 4. Access your app
curl http://localhost:3000

# Normal restarts (no db:prepare needed)
# docker compose restart web
```

### Services Configuration

**All services include:**
- ✅ Health checks (30s interval, 10s timeout, 10 retries)
- ✅ Restart policy: `unless-stopped`
- ✅ Persistent volumes in `./.srv/`
- ✅ **Docker secrets for all sensitive data**

**Services:**
- **web** - Rails 8 API (port 3000) + **YJIT enabled** + ActionCable WebSocket
- **pg** - PostgreSQL 18 Alpine + **password protected**
- **redis_cache** - Valkey 8 (Rails.cache, rate limiting) + LRU eviction
- **redis_cable** - Valkey 8 (ActionCable pub/sub) + no eviction
- **redis_session** - Valkey 8 (Access tokens, sessions) + AOF persistence
- **cloudflared** - Cloudflare Tunnel (optional, use `--profile cloudflare`)

### Security Features

**🔒 All sensitive data uses Docker secrets:**
- ✅ PostgreSQL password
- ✅ Redis Cache password (redis_cache)
- ✅ Redis Cable password (redis_cable)
- ✅ Redis Session password (redis_session)
- ✅ Rails SECRET_KEY_BASE
- ✅ Cloudflare Tunnel token

**Secrets are mounted at `/run/secrets/` inside containers (not in environment variables)**

### Private Repository Access (Optional)

If your Gemfile references private GitHub or GitLab repositories, you need to provide access tokens:

**For GitHub:**
```bash
# 1. Create Personal Access Token at: https://github.com/settings/tokens
#    Required scope: repo (Full control of private repositories)

# 2. Save token to file
echo "ghp_YOUR_TOKEN_HERE" > .secrets/github_pat
chmod 640 .secrets/github_pat

# 3. Rebuild Docker image
docker compose build
```

**For GitLab:**
```bash
# 1. Create Personal Access Token at: https://gitlab.com/-/user_settings/personal_access_tokens
#    (or your self-hosted GitLab instance)
#    Required scopes: read_api, read_repository

# 2. Save token to file
echo "glpat-YOUR_TOKEN_HERE" > .secrets/gitlab_pat
chmod 640 .secrets/gitlab_pat

# 3. For self-hosted GitLab, configure custom host
cp .env.example .env
# Edit .env and set: GITLAB_HOST=git.mycompany.com

# 4. Rebuild Docker image
docker compose build
```

**Security notes:**
- Tokens are only used during Docker build to fetch private gems
- Credentials are automatically cleaned up after `bundle install`
- Never commit token files or `.env` to git (already in .gitignore)

### Cloudflare Tunnel Setup (Optional)

Securely expose your Rails API to the internet with **WebSocket support** for ActionCable.

**Quick setup:**

```bash
# 1. Create tunnel at https://one.dash.cloudflare.com/
#    Navigate to: Access → Tunnels → Create a tunnel
#    Save the credentials JSON

# 2. Save tunnel credentials
cd .secrets
cat > cf_tunnel_token << 'EOF'
{
  "AccountTag": "your-account-tag",
  "TunnelSecret": "your-tunnel-secret",
  "TunnelID": "your-tunnel-id"
}
EOF
chmod 640 cf_tunnel_token
cd ..

# 3. Configure tunnel ingress rules
cp cloudflared-config.yaml.example cloudflared-config.yaml
# Edit cloudflared-config.yaml:
#   - Replace YOUR_TUNNEL_ID_HERE with your tunnel ID
#   - Replace api.yourdomain.com with your domain

# 4. Configure DNS (Cloudflare Dashboard)
#    Add CNAME: api.yourdomain.com → <tunnel-id>.cfargotunnel.com

# 5. Start with cloudflare profile
docker compose --profile cloudflare up -d
```

**Key features:**
- ✅ No exposed ports or public IP needed
- ✅ Automatic SSL/TLS termination
- ✅ **WebSocket support** for ActionCable real-time features
- ✅ Built-in DDoS protection
- ✅ Free tier available

**WebSocket limitations:**
- Free plan: 100s timeout (ActionCable auto-reconnects)
- Pro/Business: 600s timeout
- Enterprise: Unlimited

**For detailed setup with ActionCable configuration:**
📖 **[docs/CLOUDFLARE_TUNNEL.md](docs/CLOUDFLARE_TUNNEL.md)**

### Production Deployment

```bash
# 1. Generate secure secrets
openssl rand -base64 32 > .secrets/database_password
openssl rand -base64 32 > .secrets/redis_cache_password
openssl rand -base64 32 > .secrets/redis_cable_password
openssl rand -base64 32 > .secrets/redis_session_password
rails secret > .secrets/rails_secret_key_base

# 2. Set proper permissions (REQUIRED for Docker Compose)
chmod 700 .secrets
chmod 640 .secrets/database_password
chmod 640 .secrets/redis_*_password
chmod 640 .secrets/rails_secret_key_base
chmod 640 .secrets/cf_tunnel_token  # if using Cloudflare Tunnel

# 3. Build and deploy (first time - create database)
docker compose build
RAILS_DB_PREPARE=true docker compose up -d

# 4. Check health
docker compose ps

# 5. View logs
docker compose logs -f web

# Future deployments with schema changes
# RAILS_DB_PREPARE=true docker compose restart web
```

### File Permissions Explained

**Why not 600?**
- `chmod 600` (owner-only read) causes **permission denied** errors in Docker Compose
- Docker daemon needs to read secret files to mount them in containers
- **Cloudflared runs as non-root user** (UID 65532 in distroless image)
- Many modern containers use non-root users for security

**Recommended permissions:**
```bash
drwx------  (700)  .secrets/              # Directory: owner only
-rw-r-----  (640)  .secrets/*_password    # Files: owner rw, group r
-rw-r-----  (640)  .secrets/*_token       # Group = docker (daemon can read)
```

**Security notes:**
- Directory 700 prevents other users from **listing** secret files
- Files 640 allow Docker daemon (in docker group) to **read** secrets
- Other users cannot read secrets (no world permissions)
- This is the **industry standard** for Docker secrets on single-host deployments

### Docker Secrets Best Practices

This template uses **Docker secrets** for secure credential management:

**Security Model:**
1. **Secrets stored in files** (`.secrets/` directory)
2. **Mounted as read-only** at `/run/secrets/` inside containers
3. **Rails reads directly from files** - NO environment variable exposure
4. **Not visible in `docker inspect`** or process listings

**How it works:**
```ruby
# Rails app: No hardcoded deployment paths
password = if ENV['DATABASE_PASSWORD_FILE'] && File.exist?(ENV['DATABASE_PASSWORD_FILE'])
  File.read(ENV['DATABASE_PASSWORD_FILE']).strip
elsif ENV['DATABASE_PASSWORD']
  ENV['DATABASE_PASSWORD']
end
```

```yaml
# compose.yaml: Docker-specific defaults
environment:
  - DATABASE_PASSWORD_FILE=/run/secrets/database_password
  - REDIS_CACHE_PASSWORD_FILE=/run/secrets/redis_cache_password
  - REDIS_CABLE_PASSWORD_FILE=/run/secrets/redis_cable_password
  - REDIS_SESSION_PASSWORD_FILE=/run/secrets/redis_session_password
  - SECRET_KEY_BASE_FILE=/run/secrets/rails_secret_key_base
```

**Separation of Concerns:**
- 🎯 **App code**: Only checks if `*_FILE` env var is set (no path assumptions)
- 🐳 **Docker config**: Sets `/run/secrets/*` paths (deployment-specific)
- ☸️ **Kubernetes config**: Can override with `/etc/secrets/*` paths
- 🧪 **Testing**: Can use any custom path

**Supported `*_FILE` environment variables:**
- `DATABASE_PASSWORD_FILE` - Database password file path
- `REDIS_CACHE_PASSWORD_FILE` - Redis Cache password file path
- `REDIS_CABLE_PASSWORD_FILE` - Redis Cable password file path
- `REDIS_SESSION_PASSWORD_FILE` - Redis Session password file path
- `SECRET_KEY_BASE_FILE` - Rails secret key file path

**Benefits:**
- ✅ Secrets never appear in `docker inspect` output
- ✅ Secrets not visible to other processes
- ✅ No accidental logging of environment variables
- ✅ **App code agnostic to deployment method** (Docker, Kubernetes, bare metal)
- ✅ **Deployment config owns secret paths** (not hardcoded in app)
- ✅ Similar to PostgreSQL's official `DATABASE_PASSWORD_FILE` pattern

**Configuration Philosophy:**

| File | Purpose | Scope | Customization |
|------|---------|-------|---------------|
| **`.env`** | Application config | Any deployment | ✅ Environment variables |
| **`compose.yaml`** | Docker orchestration | Docker Compose only | ✅ Edit file or override |

**Application Config (`.env`):**
- Deployment-agnostic (works with Docker, K8s, bare metal)
- Runtime behavior (database host, Redis host, etc.)
- Secret paths **inside containers** (if non-default)

**Docker Config (`compose.yaml`):**
- Docker-specific settings (volumes, networks, health checks)
- Secret file paths **on host** (hardcoded in secrets section)
- Service definitions and dependencies

**To customize Docker secret paths:**

**Option 1: compose.override.yaml (recommended, auto-loaded)**
```yaml
# compose.override.yaml (create in project root, gitignored)
secrets:
  database_password:
    file: /vault/secrets/db_password
  redis_cache_password:
    file: /vault/secrets/redis_cache_password
  redis_cable_password:
    file: /vault/secrets/redis_cable_password
  redis_session_password:
    file: /vault/secrets/redis_session_password
```

```bash
# Automatically merged with compose.yaml
docker compose up -d
# ✅ Reads: compose.yaml + compose.override.yaml

# IMPORTANT: Does NOT work with -f flag
docker compose -f compose.yaml up -d
# ❌ Only reads: compose.yaml (override ignored!)
```

**Option 2: Edit compose.yaml directly**
```yaml
# compose.yaml
secrets:
  database_password:
    file: /mnt/vault/db_password  # Change path
```

**Option 3: Multiple compose files (explicit)**
```bash
# Useful when you need both -f flag and override
docker compose -f compose.yaml -f compose.custom.yaml up -d
```

**Environment Variable Priority** (high to low):
1. 🥇 Shell/Inline: `VAR=value docker compose up`
2. 🥈 `.env` file
3. 🥉 `compose.yaml` defaults

**Configuration Options:**

1. **Individual variables** (recommended with Docker secrets):
   ```bash
   # .env file
   DATABASE_HOST=pg
   DATABASE_PORT=5432
   DATABASE_NAME=app_production
   DATABASE_USER=postgres
   DATABASE_PASSWORD_FILE=/run/secrets/database_password
   ```

2. **Traditional URLs** (simpler but less flexible):
   ```bash
   # .env file
   DATABASE_URL=postgresql://user:pass@pg:5432/db
   REDIS_URL=redis://:pass@redis:6379/0
   ```

**Database Preparation Control:**

By default, `db:prepare` is **disabled** to speed up restarts. Enable only when needed:

```bash
# First deployment
RAILS_DB_PREPARE=true docker compose up -d

# After schema changes or migrations
RAILS_DB_PREPARE=true docker compose restart web

# Normal restarts (default - no migrations)
docker compose restart web
```

**When to set `RAILS_DB_PREPARE=true`:**
- ✅ First deployment (create database)
- ✅ After running migrations locally
- ✅ After pulling schema changes
- ❌ Normal application restarts (waste of time)

**Custom Secret Paths (No App Code Changes):**

Override paths in deployment config only:

```yaml
# Kubernetes deployment.yaml
env:
  - name: DATABASE_PASSWORD_FILE
    value: /etc/secrets/db-password
  - name: REDIS_CACHE_PASSWORD_FILE
    value: /etc/secrets/redis-cache-password
  - name: REDIS_CABLE_PASSWORD_FILE
    value: /etc/secrets/redis-cable-password
  - name: REDIS_SESSION_PASSWORD_FILE
    value: /etc/secrets/redis-session-password
  - name: SECRET_KEY_BASE_FILE
    value: /etc/secrets/app-secret
```

```yaml
# Docker Compose with Vault
environment:
  - DATABASE_PASSWORD_FILE=/vault/secrets/db_password
  - REDIS_CACHE_PASSWORD_FILE=/vault/secrets/redis_cache_password
  - REDIS_CABLE_PASSWORD_FILE=/vault/secrets/redis_cable_password
  - REDIS_SESSION_PASSWORD_FILE=/vault/secrets/redis_session_password
```

```bash
# Testing locally
export DATABASE_PASSWORD_FILE=/tmp/test-secrets/db_pass
bundle exec rails server
```

**No app code changes needed** - paths are deployment concerns only!

### Common Configuration Examples

**Example 1: Multiple environments on same host**
```bash
# .env.staging
DATABASE_NAME=app_staging
RAILS_ENV=staging
REDIS_DB=1

# .env.production
DATABASE_NAME=app_production
RAILS_ENV=production
REDIS_DB=0

# Deploy staging
docker compose --env-file .env.staging up -d

# Deploy production
docker compose --env-file .env.production -p app_prod up -d
```

**Example 2: External managed services**
```bash
# .env - Using AWS RDS and ElastiCache
DATABASE_HOST=myapp.abc123.us-east-1.rds.amazonaws.com
DATABASE_PORT=5432
DATABASE_NAME=production_db

# Multiple Redis instances (or single ElastiCache cluster with different databases)
REDIS_CACHE_HOST=myapp-cache.abc123.cache.amazonaws.com
REDIS_CABLE_HOST=myapp-cable.abc123.cache.amazonaws.com
REDIS_SESSION_HOST=myapp-session.abc123.cache.amazonaws.com

# Secrets still use files
DATABASE_PASSWORD_FILE=/run/secrets/rds_password
REDIS_CACHE_PASSWORD_FILE=/run/secrets/elasticache_cache_password
REDIS_CABLE_PASSWORD_FILE=/run/secrets/elasticache_cable_password
REDIS_SESSION_PASSWORD_FILE=/run/secrets/elasticache_session_password
```

**Example 3: Development with local services**
```bash
# .env.local - Override for local development
DATABASE_HOST=localhost
DATABASE_PORT=5432
REDIS_CACHE_HOST=localhost
REDIS_CABLE_HOST=localhost
REDIS_SESSION_HOST=localhost
RAILS_ENV=development

# Don't use secrets in development
# Just export: DATABASE_PASSWORD=dev_password
# REDIS_CACHE_PASSWORD=cache_password, etc.
```

### Performance Optimization

**YJIT Enabled by Default:**
- Ruby 3.4 YJIT provides 15-30% performance improvement
- Automatically enabled via `RUBY_YJIT_ENABLE=1`
- No additional configuration needed

**Verify YJIT is active:**
```bash
docker compose exec web rails runner 'puts RubyVM::YJIT.enabled?'
# Should output: true
```

### Multi-Environment Deployment

**File Organization:**

| File | Purpose | Committed | Auto-loaded |
|------|---------|-----------|-------------|
| `compose.yaml` | Base configuration | ✅ Yes | ✅ Yes |
| `compose.production.yaml` | Production overrides | ✅ Yes | ❌ No |
| `compose.staging.yaml` | Staging overrides | ✅ Yes | ❌ No |
| `compose.dev.yaml` | Shared dev config | ✅ Yes | ❌ No |
| `compose.override.yaml` | Personal overrides | ❌ No (gitignored) | ✅ Yes |
| `compose.local.yaml` | Personal explicit | ❌ No (gitignored) | ❌ No |

**Usage:**

```bash
# Development (base + auto override)
docker compose up -d
# Loads: compose.yaml + compose.override.yaml (if exists)

# Development (shared team config)
docker compose -f compose.yaml -f compose.dev.yaml up -d

# Staging
docker compose -f compose.yaml -f compose.staging.yaml up -d

# Production
docker compose -f compose.yaml -f compose.production.yaml up -d

# Personal override (explicit)
docker compose -f compose.yaml -f compose.local.yaml up -d
```

**Best Practice Patterns:**

```yaml
# compose.override.yaml (gitignored - personal dev)
services:
  web:
    volumes:
      - .:/app  # Live code reload
  pg:
    ports:
      - "5432:5432"  # Debug access

# compose.dev.yaml (committed - team shared)
services:
  web:
    environment:
      - RAILS_ENV=development
    volumes:
      - .:/app

# compose.staging.yaml (committed)
services:
  web:
    environment:
      - RAILS_ENV=staging
      - DATABASE_NAME=app_staging

# compose.production.yaml (committed)
services:
  web:
    environment:
      - RAILS_ENV=production
    deploy:
      replicas: 3
```

## Valkey/Redis Architecture

This template uses **Valkey 8** (100% Redis-compatible, fully open source) with **three separate instances** for different use cases:

### Valkey Instances

| Instance | Purpose | Memory | Eviction Policy | Persistence | Port |
|----------|---------|--------|----------------|-------------|------|
| **redis_cache** | Rails.cache, Rack::Attack rate limiting | 1GB | `allkeys-lru` | No | 6379 |
| **redis_cable** | ActionCable WebSocket pub/sub | 512MB | `noeviction` | No | 6379 |
| **redis_session** | Access tokens, user sessions | 512MB | `noeviction` | AOF (everysec) | 6379 |

### Why Three Separate Instances?

**Problem with single Redis:**
- ❌ **Eviction conflicts**: Cache needs LRU eviction, sessions cannot be evicted
- ❌ **FLUSHDB risk**: Clearing cache (`FLUSHDB`) would delete sessions
- ❌ **Monitoring difficulty**: Cannot track memory usage per use case
- ❌ **Fault isolation**: Cache failure affects sessions

**Benefits of separation:**
- ✅ **Different eviction policies**: Cache can evict old data, sessions are protected
- ✅ **Different persistence needs**: Sessions persisted to disk, cache is ephemeral
- ✅ **Fault isolation**: Cache failure doesn't affect WebSocket or sessions
- ✅**Independent scaling**: Scale cache vs sessions separately based on usage
- ✅ **Clear monitoring**: Track memory, hit rate, connections per instance

### Configuration Examples

**Rails.cache (redis_cache):**
```ruby
# Automatic expiration of old data to make room for new cache entries
Rails.cache.write('trending_posts', posts, expires_in: 1.hour)
```

**ActionCable (redis_cable):**
```ruby
# Real-time pub/sub messages (ephemeral, no persistence needed)
ActionCable.server.broadcast("notifications:#{user_id}", data)
```

**User sessions (redis_session):**
```ruby
# Access tokens that must never be evicted (persisted with AOF)
REDIS_SESSION.with { |r| r.setex("token:#{token}", 24.hours.to_i, user_id) }
```

### Memory Guidelines

**Total Redis memory: ~2GB** (1GB cache + 512MB cable + 512MB session)

**Scaling guidelines:**
- **< 1,000 users**: Default settings (2GB total)
- **1,000-10,000 users**: 2GB cache + 1GB cable + 1GB session
- **10,000-100,000 users**: 4GB cache + 2GB cable + 2GB session
- **100,000+ users**: Consider Redis cluster or managed service

**For detailed architecture explanation, troubleshooting, and scaling guides:**
📖 **[docs/REDIS_ARCHITECTURE.md](docs/REDIS_ARCHITECTURE.md)**

## Resource ID Strategy

This template uses **UUIDv7** as the default primary key type for all database tables, leveraging PostgreSQL 18's native support.

### Why UUIDv7 Over Auto-Incrementing IDs?

**Business Intelligence Leakage Risk:**

```ruby
# ❌ Problem: Sequential integer IDs expose business data
GET /api/orders/12345  # → Reveals: "~12,345 total orders"

# One week later
GET /api/orders/12850  # → Reveals: "~500 orders/week growth"
```

**Competitors can:**
- 📊 Estimate your business scale
- 📈 Track your growth/decline rate
- 🔍 Perform enumeration attacks

### UUIDv7: Security + Performance

**Performance comparison (1M row insert):**
```
┌──────────┬──────────┬────────────────┐
│ Type     │ Time     │ Relative       │
├──────────┼──────────┼────────────────┤
│ bigint   │ 290 sec  │ 100% (baseline)│
│ UUIDv7   │ 290 sec  │ 100% ✅ SAME!  │
│ UUIDv4   │ 375 sec  │ 77% (slower)   │
└──────────┴──────────┴────────────────┘
```

**UUIDv7 = bigint performance + security**

### Implementation

All models automatically use UUIDs:

```ruby
# rails g model Order user:references status:string

# Generated migration:
create_table :orders, id: :uuid do |t|
  t.references :user, type: :uuid, foreign_key: true
  t.string :status
  t.timestamps
end

# Model usage (no changes needed):
order = Order.create(user: current_user, status: 'pending')
order.id  # => "018f4d9e-5c4a-7000-9f8b-3a4c5d6e7f8a"
```

### Selective Opt-Out

Use bigint for internal tables if needed:

```ruby
# Opt-out: Use bigint for join tables
create_table :join_table, id: :bigint do |t|
  t.references :order, type: :uuid
  t.references :product, type: :uuid
end
```

**For complete ID strategy guide including:**
- UUIDv7 vs bigint vs ULID comparison
- Performance benchmarks and analysis
- Security best practices
- Migration examples
- When to use each ID type

📖 **[docs/ID_STRATEGY.md](docs/ID_STRATEGY.md)**

## Authentication Architecture

This template provides comprehensive documentation for implementing access token authentication using a **hybrid Redis + PostgreSQL approach**.

### Recommended Architecture

**Storage Strategy:**
- **PostgreSQL**: Token digest, metadata, audit trail (source of truth)
- **Redis (redis_session)**: Token → user_id mapping (performance cache)

**Workflow:**
1. **Login**: Generate token → Save to PostgreSQL → Cache in Redis
2. **Request**: Check Redis (< 1ms) → Fallback to PostgreSQL (5-20ms)
3. **Logout**: Delete from both Redis and PostgreSQL

**Benefits:**
- ⚡ **Fast**: 95%+ requests served from Redis (< 1ms)
- 🔒 **Reliable**: PostgreSQL ensures no data loss
- 🚀 **Scalable**: Redis handles high request rates
- 📊 **Auditable**: PostgreSQL tracks token history
- 🛡️ **Recoverable**: Works even if Redis fails

### Why Not JWT-only?

**JWT (JSON Web Tokens) cannot be revoked** until expiration:

```
User: "My account was hacked!"
You: "I'll revoke all sessions immediately"
Reality: ❌ Cannot revoke JWT tokens
Hacker: Still has valid JWT for next 24 hours
```

**Why Not Redis-only?**

```
Redis crashes/restarts
→ All 10,000 active users: ❌ Logged out immediately
→ Support tickets: 📈📈📈
→ Lost all session data forever
```

### Implementation

This template **does not include** authentication implementation code - only comprehensive documentation explaining:

- Token generation strategy (opaque tokens with SHA256 digest)
- Token verification flow (Redis fast path, PostgreSQL fallback)
- Security best practices (entropy, expiration, never store plaintext)
- Performance optimization (cache hit rate, async updates)
- Alternative approaches comparison

**For complete authentication guide with examples and best practices:**
📖 **[docs/AUTHENTICATION.md](docs/AUTHENTICATION.md)**

### Using redis_session for Tokens

The `redis_session` instance is pre-configured for access token storage:

```ruby
# Example: Store access token (conceptual)
REDIS_SESSION.with do |redis|
  redis.setex(
    "token:#{raw_token}",
    24.hours.to_i,
    user_id.to_s
  )
end

# Verify token (conceptual)
user_id = REDIS_SESSION.with { |r| r.get("token:#{token}") }
```

**Note**: This is **conceptual code only**. Implement based on your specific requirements following the guide in `docs/AUTHENTICATION.md`.

## Rate Limiting

This template includes **rack-attack** gem for API rate limiting, but **does not provide default configuration**.

### Why No Default Configuration?

**Every application has different requirements:**
- Public API vs Private API (different traffic patterns)
- Anonymous vs Authenticated users (different restriction strategies)
- Free vs Pro tiers (subscription models require dynamic limits)
- Resource-intensive endpoints (different endpoints need different limits)

**Risks of default configuration:**
- ❌ Too strict: False positives blocking legitimate users
- ❌ Too loose: Cannot defend against attacks
- ❌ One-size-fits-all: Not suitable for all scenarios

### Configuration Required

**You must configure rate limiting based on your needs:**

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Example: IP-based throttling
  throttle('api/ip', limit: 100, period: 1.minute) do |req|
    req.ip
  end

  # Example: User-based throttling
  throttle('api/user', limit: 1000, period: 1.hour) do |req|
    req.env['warden']&.user&.id
  end

  # Example: Login protection
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == '/api/v1/login' && req.post?
  end
end
```

### Comprehensive Documentation

**Complete best practices guide covers:**
- **Strategy Selection**: IP-based vs User-based vs Endpoint-based
- **Algorithm Comparison**: Fixed Window, Sliding Window, Token Bucket, Leaky Bucket
- **Scenario Examples**:
  - Public API
  - Private API (authenticated users)
  - Login endpoint protection (prevent credential stuffing)
  - Expensive operations (file uploads, report generation)
  - WebSocket connection limits
  - Subscription-based API (Free/Pro/Enterprise tiers)
- **Cloudflare Integration**: Two-layer defense (edge + application layer)
- **Testing Methods**: RSpec, load testing, curl testing
- **Monitoring**: Prometheus metrics, alert rules
- **Troubleshooting**: Common issues and solutions

📖 **[docs/RATE_LIMITING.md](docs/RATE_LIMITING.md)**

### Redis Integration (Pre-configured)

Rack::Attack automatically uses `Rails.cache` (configured as `redis_cache`):

```ruby
# gem/redis.rb (already configured)
Rails.application.config.cache_store = :redis_cache_store, {
  url: cache_url,
  pool_size: pool_size
}

# Rack::Attack uses Rails.cache automatically
# → All servers share the same counter (distributed rate limiting)
```

**No additional configuration needed** - Redis is already correctly configured for Rack::Attack.

## Zero-Downtime Deployment

When updating applications in production, **zero-downtime deployment** is a critical requirement. Since old and new versions run simultaneously for a period, backward compatibility must be ensured.

**Core Challenges:**
- V1 and V2 containers handle requests simultaneously
- Database schema must support both old and new versions
- API response format cannot break backward compatibility

**Key Strategies:**
- **Expand-Contract Pattern**: Three-phase database changes
- **Backward Compatibility**: New version reads old data, old version handles new data
- **Health Checks**: Liveness and Readiness probes
- **Graceful Shutdown**: Complete existing requests before shutdown

**Complete guide covers:**
- Database migration safety strategies (add/delete/rename columns)
- Rolling/Blue-Green/Canary deployment
- Common pitfalls (NOT NULL constraints, Enum changes, API format changes)
- Production checklist

📖 **[docs/ZERO_DOWNTIME_DEPLOYMENT.md](docs/ZERO_DOWNTIME_DEPLOYMENT.md)**

## Per-Request Global State (CurrentAttributes)

Rails built-in **ActiveSupport::CurrentAttributes** provides thread-safe per-request global storage without needing the `request_store` gem.

### Common Use Cases

**Suitable for CurrentAttributes:**
- `current_user` - Access current user in Service Objects
- `current_account` - Account isolation in multi-tenant applications
- `request_id` - Request tracking and log correlation
- `timezone` - Automatically set user timezone

**Basic Example:**
```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :account, :request_id
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  before_action :set_current_user

  private

  def set_current_user
    Current.user = authenticate_user
  end
end

# Use anywhere (no need to pass parameters)
class OrderService
  def create_order(params)
    Order.create!(params.merge(user_id: Current.user.id))
  end
end
```

**Why not use request_store gem?**
- ✅ Built-in feature since Rails 5.2+
- ✅ Type safe (attribute vs Hash)
- ✅ Officially maintained and supported
- ✅ No additional dependencies

**Complete guide covers:**
- Multi-tenant application examples
- Log tracking integration
- Best practices and considerations
- Testing strategies

📖 **[docs/CURRENT_ATTRIBUTES.md](docs/CURRENT_ATTRIBUTES.md)**

## Input Normalization

User input often contains **unexpected leading/trailing whitespace**, requiring normalization to ensure data consistency and query accuracy.

### Common Issues

**Consequences of not handling whitespace:**
- ❌ Search failures: `User.find_by(email: "john@example.com")` won't find `" john@example.com "`
- ❌ Duplicate data: `"John"` and `" John "` treated as different values
- ❌ Validation errors: uniqueness validation can't prevent both `"user"` and `" user "`

### Rails 7.1+ normalizes (Recommended)

Official API introduced in Rails 7.1+ that automatically normalizes attributes before validation:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # Basic: strip leading/trailing whitespace
  normalizes :name, :username, with: -> value { value.strip }

  # Combine multiple normalizations
  normalizes :email, with: -> email { email.strip.downcase }

  # Phone number: remove non-digit characters
  normalizes :phone, with: -> phone { phone.gsub(/\D/, '') }

  validates :email, presence: true, uniqueness: true
end
```

**Automatic query normalization:**
```ruby
# Create user
user = User.create!(email: " JOHN@EXAMPLE.COM ")
# → Saved as: "john@example.com"

# Query automatically normalized
User.find_by(email: "  JOHN@EXAMPLE.COM  ")
# → Automatically converts query condition, finds user ✅
```

### Complete Documentation

**Detailed implementation guide covers:**
- **Solution Comparison**: normalizes vs Model Callback vs Strong Parameters vs Gem
- **Fields NOT to normalize**: passwords, JSON, free text, code
- **Common Scenarios**:
  - Complete email normalization (strip + downcase + unicode normalize)
  - Username, phone number, URL/Slug
  - Search form parameter handling
  - Multi-language content
- **Testing Strategies**: create, query, uniqueness validation
- **Performance Considerations**: Benchmarks and optimization recommendations
- **Decision table and checklist**

📖 **[docs/INPUT_NORMALIZATION.md](docs/INPUT_NORMALIZATION.md)**

## N+1 Query Detection (Prosopite)

This template uses **Prosopite** to automatically detect N+1 queries in RSpec tests, featuring **zero false positives/negatives** (recommended by Evil Martians 2025).

### Why Detect in Tests?

**Advantages of detection in tests:**
- ✅ Ensures test-covered code has no N+1 issues
- ✅ Doesn't interfere with normal development requests
- ✅ Automatically fails in CI/CD, preventing N+1 from reaching production
- ✅ Developers can selectively run specific tests for detection

**Configuration:**
```ruby
# Already configured in spec/support/prosopite.rb
# All request specs are automatically wrapped by Prosopite
RSpec.configure do |config|
  config.around(:each, type: :request) do |example|
    Prosopite.scan
    example.run
  ensure
    Prosopite.finish
  end
end
```

### Usage Example

**Detecting N+1 queries:**
```ruby
# spec/requests/users_spec.rb
RSpec.describe "GET /api/users", type: :request do
  before do
    create_list(:user, 10) do |user|
      create_list(:post, 3, user: user)
    end
  end

  it "lists all users with post counts" do
    get "/api/users"

    # ❌ If controller has N+1 query, test will fail
    # users.each { |u| u.posts.count }  # N+1 detected!

    # ✅ Correct approach: use eager loading
    # User.includes(:posts)

    expect(response).to have_http_status(:ok)
  end
end
```

**Fixing N+1 queries:**
```ruby
# app/controllers/api/users_controller.rb
class Api::UsersController < ApplicationController
  def index
    # ❌ N+1 query
    # @users = User.all

    # ✅ Eager loading
    @users = User.includes(:posts)

    render json: @users
  end
end
```

### Alternative: Rails Built-in strict_loading

For critical queries, use Rails built-in `strict_loading`:

```ruby
# Query level
User.strict_loading.find(1).posts
# → Raises ActiveRecord::StrictLoadingViolationError

# Model level
class User < ApplicationRecord
  has_many :posts, strict_loading: true
end
```

### Common N+1 Fix Patterns

**1. Use eager loading (includes):**
```ruby
# ❌ N+1 query
@users = User.all
@users.each { |u| u.posts.count }

# ✅ Eager loading
@users = User.includes(:posts).all
@users.each { |u| u.posts.count }
```

**2. Use counter cache:**
```ruby
# ❌ Query every time
user.posts.count

# ✅ Counter cache
class Post < ApplicationRecord
  belongs_to :user, counter_cache: true
end
user.posts_count  # No query!
```

**3. Load only needed columns (select):**
```ruby
# ❌ Load all columns
User.all

# ✅ Load only needed data
User.select(:id, :name, :email)
```

**4. Use pluck for simple data extraction:**
```ruby
# ❌ Instantiate AR objects
User.all.map(&:email)

# ✅ Direct SQL, no AR overhead
User.pluck(:email)
```

**5. Batch process large datasets:**
```ruby
# ❌ Load all records
User.all.each { |u| process(u) }

# ✅ Batch processing (1000 per batch)
User.find_each(batch_size: 1000) { |u| process(u) }
```

### Real-World Benefits

**Evil Martians case study:**
> "After removing N+1 queries, application latency improved by 2x"

**Typical improvements:**
- N+1 fixes: Response time improvement **50-90%**
- Proper eager loading: Query count reduction **10-100x**
- Counter cache: count queries reduction **100%**

## Debugging

This template uses Ruby's official **debug** gem (standard since Ruby 3.1) instead of pry-rails:

```ruby
# Add breakpoints in your code
binding.break  # or just 'debugger'

# Available commands in debug session:
# step (s)     - Step into method calls
# next (n)     - Next line
# continue (c) - Continue execution
# break (b)    - Set breakpoint
# info (i)     - Show information
# quit (q)     - Exit debugger
```

**Why not pry-rails?**
- pry-rails is no longer maintained
- Rails 8 + Ruby 3.4 has powerful built-in IRB with syntax highlighting and autocomplete
- `debug` gem is officially supported with VS Code integration (vscode-rdbg)

**For phone validation:** This template doesn't include phonelib by default. For most API projects:
- Use frontend validation (libphonenumber-js)
- Backend stores pre-validated E.164 format
- Add phonelib only if you need server-side international phone parsing
