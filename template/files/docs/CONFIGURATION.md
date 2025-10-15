# Configuration Management Guide

This template uses **three separate configuration systems** for different purposes.

## Configuration Systems Overview

| System | Purpose | File Location | Committed to Git | When to Use |
|--------|---------|---------------|------------------|-------------|
| **ENV** | Environment config | `.env` | ❌ No | Host, port, database, threads, CORS |
| **Docker Secrets** | Sensitive data | `.secrets/` | ❌ No | Passwords, API keys, tokens |
| **Settings** | Business logic | `config/settings.yml` | ✅ Yes | Timeout, limits, rules, feature flags |

## 1. ENV Variables (.env)

**Purpose:** Environment-specific configuration that changes between dev/staging/production.

**Examples:**
- Database connection: `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USER`
- Redis connections: `REDIS_CACHE_HOST`, `REDIS_SESSION_HOST`
- Server settings: `RAILS_MAX_THREADS`, `WEB_CONCURRENCY`
- CORS: `CORS_ORIGINS`
- Time zone: `TIME_ZONE`

**Setup:**
```bash
# Local development
cp .env.local.example .env
nano .env

# Docker deployment
# Uses .env.example (root directory)
```

**Usage in code:**
```ruby
# config/database.yml
pool: <%= ENV.fetch('RAILS_MAX_THREADS', 16).to_i %>
host: <%= ENV.fetch('DATABASE_HOST', 'localhost') %>

# config/application.rb
config.time_zone = ENV.fetch('TIME_ZONE', 'UTC')

# config/initializers/cors.rb
origins ENV.fetch('CORS_ORIGINS', '*').split(',').map(&:strip)
```

## 2. Docker Secrets (.secrets/)

**Purpose:** Sensitive credentials that must never be committed to git.

**Examples:**
- `database_password` - PostgreSQL password
- `redis_cache_password`, `redis_cable_password`, `redis_session_password`
- `rails_secret_key_base` - Rails encryption key
- `mailer_smtp_password` - SMTP password for Action Mailer
- `cf_tunnel_token` - Cloudflare Tunnel credentials (optional)

**Setup:**
```bash
cd .secrets
for file in *.example; do cp "$file" "${file%.example}"; done

# Generate passwords
openssl rand -base64 32 > database_password
openssl rand -base64 32 > redis_cache_password
# ... (see .secrets/README.md for complete setup)

# Set permissions
chmod 700 .
chmod 640 *_password *_base
```

**Usage in code:**
```ruby
# config/database.yml
password: <%=
  if ENV['DATABASE_PASSWORD_FILE'] && File.exist?(ENV['DATABASE_PASSWORD_FILE'])
    File.read(ENV['DATABASE_PASSWORD_FILE']).strip
  elsif ENV['DATABASE_PASSWORD']
    ENV['DATABASE_PASSWORD']
  else
    ''
  end
%>

# config/application.rb
config.secret_key_base = if ENV['SECRET_KEY_BASE_FILE']
  File.read(ENV['SECRET_KEY_BASE_FILE']).strip
else
  ENV.fetch('SECRET_KEY_BASE')
end
```

## 3. Settings (config/settings.yml)

**Purpose:** Business logic configuration that is the same across environments (or varies intentionally by environment).

**When to use Settings:**
- ✅ Token expiration times: `Settings.access_token_expired_time`
- ✅ Business limits: `Settings.max_upload_size`, `Settings.max_retry_times`
- ✅ Feature flags: `Settings.enable_chatgpt`, `Settings.enable_sentry`
- ✅ Business rules: `Settings.allowed_ip_addresses`, `Settings.default_avatar_url`
- ✅ Timeout settings: `Settings.job_timeout`, `Settings.api_timeout`
- ✅ Application constants: `Settings.customer_service_url`

**When NOT to use Settings:**
- ❌ Database connection details (use ENV)
- ❌ Redis host/port (use ENV)
- ❌ Passwords/tokens (use Docker Secrets)
- ❌ Server threads/workers (use ENV)

**Example settings.yml:**
```yaml
# config/settings.yml (default template only has pg_db_prefix)
pg_db_prefix: myapp  # Database name prefix (business logic)

# Add your business configuration as needed:
# access_token_expired_time: 86400  # 1 day
# max_upload_size: 10485760  # 10MB
# enable_feature_x: false
# job_timeout: 300  # 5 minutes
# default_avatar_url: "https://example.com/avatar.png"
```

**Usage in code:**
```ruby
# app/models/access_token.rb
def expired?
  created_at < Settings.access_token_expired_time.seconds.ago
end

# app/controllers/uploads_controller.rb
def validate_file_size
  if file.size > Settings.max_upload_size
    render json: { error: "File too large" }, status: :unprocessable_entity
  end
end
```

## Configuration Decision Tree

```
Is this configuration...

├─ A password, API key, or secret token?
│  └─ ✅ Use Docker Secrets (.secrets/)
│
├─ Environment-specific (host, port, database)?
│  └─ ✅ Use ENV (.env)
│
├─ Business logic (timeout, limit, rule)?
│  └─ ✅ Use Settings (settings.yml)
│
└─ Not sure?
   └─ Ask: "Does this change between dev/staging/prod?"
      ├─ Yes → ENV
      └─ No → Settings
```

## Real-World Examples

### Example: Booking/Reservation Platform

```yaml
# ✅ Settings (settings.yml) - Business logic
access_token_expired_time: 10800  # 3 hours
reservation_rating_edit_expired_time: 1296000  # 15 days
reservation_rating_max_edit_times: 2
deposit_limit: 100000  # Max deposit amount
calendar_max_date_range: 31  # Calendar view max days
antiabuse_reaction_limit: 10
customer_service_url: "https://support.example.com"

# ❌ Should be ENV
# pg_host: "localhost"  # This is environment config!
# pg_password: ""  # This is sensitive data!
```

### Example: Data Processing Platform

```yaml
# ✅ Settings (settings.yml) - Business logic
dataset_min_sample_size: 10
dataset_max_sample_size: 3000
max_items_per_batch: 3
processing_job_timeout: 300  # 5 hours
bulk_processing_timeout: 1800  # 30 hours
email_confirmation_expired_time: 300  # 5 minutes
throttling_max_retry_times: 20

admin_allowed_ips:
  - '*'

# ❌ Should be ENV
# pg_host: "localhost"
# mailer_smtp_address: "smtp.mailgun.org"  # Environment config
```

## Migration Guide

### Migrating Existing Projects

If you have an existing project with settings.yml containing environment config:

1. **Identify configuration type:**
   ```bash
   # Review settings.yml
   cat config/settings.yml

   # Separate into: ENV, Secrets, Settings
   ```

2. **Move environment config to .env:**
   ```bash
   # Create .env
   echo "DATABASE_HOST=localhost" >> .env
   echo "DATABASE_PORT=5432" >> .env
   # ...
   ```

3. **Move secrets to .secrets/:**
   ```bash
   cd .secrets
   echo "your_db_password" > database_password
   chmod 640 database_password
   ```

4. **Keep business logic in settings.yml:**
   ```yaml
   # config/settings.yml
   access_token_expired_time: 86400
   max_upload_size: 10485760
   # ...
   ```

5. **Update code:**
   ```ruby
   # Before
   Settings.pg_host

   # After
   ENV.fetch('DATABASE_HOST', 'localhost')
   ```

## Best Practices

1. **Never commit sensitive data:**
   - ✅ `.env` and `.secrets/` are in `.gitignore`
   - ❌ Never put passwords in `settings.yml`

2. **Use defaults appropriately:**
   ```ruby
   # ENV: Provide sensible defaults
   ENV.fetch('RAILS_MAX_THREADS', 16).to_i

   # Settings: No defaults (fail fast if missing)
   Settings.api_timeout  # Raises error if not configured
   ```

3. **Document your settings:**
   ```yaml
   # config/settings.yml
   # Token expiration time (seconds)
   access_token_expired_time: 86400  # 1 day

   # Maximum file upload size (bytes)
   max_upload_size: 10485760  # 10MB
   ```

4. **Environment-specific settings (if needed):**
   ```yaml
   # config/settings.yml
   default: &default
     max_upload_size: 10485760

   development:
     <<: *default
     enable_debug_mode: true

   production:
     <<: *default
     enable_debug_mode: false
   ```

## Summary

| Configuration Type | Storage | Example | Committed |
|-------------------|---------|---------|-----------|
| **Environment** | `.env` | `DATABASE_HOST=localhost` | ❌ |
| **Sensitive** | `.secrets/` | `database_password` | ❌ |
| **Business Logic** | `settings.yml` | `access_token_expired_time: 86400` | ✅ |

**Golden Rule:**
- Secrets → Docker Secrets
- Environment → ENV
- Business → Settings

For detailed setup instructions:
- ENV: See `.env.local.example`
- Secrets: See `.secrets/README.md`
- Settings: See `config/settings.yml` (add as needed)
