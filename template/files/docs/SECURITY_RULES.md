# Security Rules for Path Scanning Protection

## Overview

Malicious users often attempt to access sensitive file paths, such as:
- `/config/.env` - Environment variables
- `/logs/app.log` - Log files
- `/backup/database.sql` - Backup files
- `/.git/config` - Git configuration
- `/aws-export.js` - AWS credentials

This document provides multi-layer defense strategies.

## 1. Cloudflare WAF Rules

### Basic Protection Rules

Create WAF rules in Cloudflare Dashboard:

**Security > WAF > Custom rules > Create rule**

```javascript
// Rule Name: Block Sensitive File Access
// Expression:
(
  http.request.uri.path contains "/.env" or
  http.request.uri.path contains "/.git" or
  http.request.uri.path contains "/config/" or
  http.request.uri.path contains "/logs/" or
  http.request.uri.path contains "/backup" or
  http.request.uri.path contains "/dump" or
  http.request.uri.path contains ".log" or
  http.request.uri.path contains ".sql" or
  http.request.uri.path contains ".bak" or
  http.request.uri.path contains "aws" or
  http.request.uri.path contains "credentials" or
  http.request.uri.path contains "secret" or
  http.request.uri.path contains ".pem" or
  http.request.uri.path contains ".key" or
  http.request.uri.path contains "docker-compose" or
  http.request.uri.path contains "compose.yaml" or
  http.request.uri.path contains "Dockerfile" or
  http.request.uri.path contains ".secrets/" or
  http.request.uri.path contains "wp-admin" or
  http.request.uri.path contains "phpmyadmin" or
  http.request.uri.path contains "admin.php"
)

// Action: Block (HTTP 403)
```

### Advanced Rules

```javascript
// Rule Name: Block Directory Traversal
(
  http.request.uri.path contains "../" or
  http.request.uri.path contains "..%2F" or
  http.request.uri.path contains "%2e%2e" or
  http.request.uri.path contains "..\\" or
  http.request.uri.path contains "..%5C"
)
// Action: Block

// Rule Name: Block Exploitation Patterns
(
  http.request.uri.path matches "(?i)\\.(php|asp|aspx|jsp|cgi)$" or
  http.request.uri.query contains "union select" or
  http.request.uri.query contains "base64_decode" or
  http.request.uri.query contains "eval(" or
  http.request.uri.query contains "<script"
)
// Action: Block

// Rule Name: Block Known Scanners
(
  lower(http.user_agent) contains "sqlmap" or
  lower(http.user_agent) contains "nikto" or
  lower(http.user_agent) contains "nmap" or
  lower(http.user_agent) contains "masscan" or
  lower(http.user_agent) contains "acunetix" or
  lower(http.user_agent) contains "scanner" or
  lower(http.user_agent) contains "bot" and not lower(http.user_agent) contains "googlebot"
)
// Action: Managed Challenge
```

### Rate Limiting (Scanner Protection)

**Security > WAF > Rate limiting rules**

```javascript
// Rule Name: Throttle Path Scanning
// Expression:
(http.response.code eq 404) and
(
  http.request.uri.path contains "/config" or
  http.request.uri.path contains "/.env" or
  http.request.uri.path contains "/backup" or
  http.request.uri.path contains "/logs" or
  http.request.uri.path contains ".git"
)

// Characteristics: IP Address
// Period: 10 seconds
// Requests: 10
// Action: Block
// Mitigation timeout: 3600 seconds (1 hour)
```

### Managed Rulesets

Enable Cloudflare default rules:

```
Cloudflare Dashboard > Security > WAF > Managed rules

✅ Cloudflare Managed Ruleset
✅ Cloudflare OWASP Core Ruleset
✅ Cloudflare Exposed Credentials Check
```

### Newly Discovered Attack Patterns (Based on Real Data Analysis)

Based on real attack data analysis, here are additional attack protection patterns:

#### Framework-Specific Attacks

```javascript
// Rule Name: Block Framework Exploits
// Expression:
(
  // Laravel
  http.request.uri.path contains "/_ignition/execute-solution" or
  http.request.uri.path contains "/_ignition/health-check" or
  http.request.uri.path contains "/telescope" or
  http.request.uri.path contains "/horizon" or
  http.request.uri.path contains "/storage/logs/" or
  http.request.uri.path contains "/artisan" or

  // Symfony
  http.request.uri.path contains "/_profiler" or
  http.request.uri.path contains "/app_dev.php" or

  // Spring Boot
  http.request.uri.path contains "/actuator/env" or
  http.request.uri.path contains "/actuator/heapdump" or
  http.request.uri.path contains "/actuator/gateway" or
  http.request.uri.path contains "/actuator/mappings" or

  // Struts
  http.request.uri.path matches ".*\\.action$" or
  http.request.uri.path matches ".*\\.do$" or

  // Nacos
  http.request.uri.path contains "/nacos/"
)
// Action: Block
```

#### Development Tool Configuration Attacks

```javascript
// Rule Name: Block Dev Tool Configs
// Expression:
(
  // CI/CD configs
  http.request.uri.path contains "/.gitlab-ci.yml" or
  http.request.uri.path contains "/.travis.yml" or
  http.request.uri.path contains "/.circleci/" or
  http.request.uri.path contains "/.github/workflows/" or
  http.request.uri.path contains "/.drone.yml" or
  http.request.uri.path contains "/jenkins" or

  // IDE configs
  http.request.uri.path contains "/.vscode/" or
  http.request.uri.path contains "/.idea/" or
  http.request.uri.path contains "/.settings/" or
  http.request.uri.path contains "/.project" or
  http.request.uri.path contains "/.classpath" or

  // Node.js configs
  http.request.uri.path contains "/package.json" or
  http.request.uri.path contains "/package-lock.json" or
  http.request.uri.path contains "/yarn.lock" or
  http.request.uri.path contains "/.npmrc" or
  http.request.uri.path contains "/node_modules/"
)
// Action: Block
```

#### Application Configs and Database Files

```javascript
// Rule Name: Block App Configs and DB Files
// Expression:
(
  // Application configs
  http.request.uri.path matches ".*config\\.(json|yml|yaml|xml)$" or
  http.request.uri.path contains "/application.properties" or
  http.request.uri.path contains "/application.yml" or
  http.request.uri.path contains "/appsettings.json" or
  http.request.uri.path contains "/web.config" or
  http.request.uri.path contains "/settings.json" or

  // Database files
  http.request.uri.path contains "/database.yml" or
  http.request.uri.path matches ".*\\.(sqlite|sqlite3|db|mdb)$"
)
// Action: Block
```

#### Search Engines and Monitoring Systems

```javascript
// Rule Name: Block Search Engines and Monitoring
// Expression:
(
  // Search engines
  http.request.uri.path contains "/solr/" or
  http.request.uri.path contains "/elasticsearch/" or
  http.request.uri.path contains "/kibana/" or
  http.request.uri.path contains "/_cat/" or
  http.request.uri.path contains "/_search" or

  // Monitoring systems
  http.request.uri.path contains "/nagios/" or
  http.request.uri.path contains "/zabbix/" or
  http.request.uri.path contains "/prometheus/" or
  http.request.uri.path contains "/grafana/"
)
// Action: Block
// Note: If your application has legitimate /metrics endpoints, set up whitelist separately
```

#### File Managers and System Files

```javascript
// Rule Name: Block File Managers and System Files
// Expression:
(
  // File managers
  http.request.uri.path contains "/kcfinder/" or
  http.request.uri.path contains "/elfinder/" or
  http.request.uri.path contains "/filemanager/" or
  http.request.uri.path contains "/tinymce/" or

  // System files
  http.request.uri.path contains "/etc/passwd" or
  http.request.uri.path contains "/etc/shadow" or
  http.request.uri.path contains "/etc/hosts" or
  http.request.uri.path contains "/proc/self" or
  http.request.uri.path contains "/proc/cpuinfo" or
  http.request.uri.path contains "/windows/win.ini" or
  http.request.uri.path contains "/windows/system.ini"
)
// Action: Block
```

#### Test and Debug Paths

```javascript
// Rule Name: Block Test and Debug Paths
// Expression:
(
  http.request.uri.path contains "/debug" or
  http.request.uri.path contains "/demo" or
  http.request.uri.path contains "/dev/" or
  http.request.uri.path contains "/test" or
  http.request.uri.path contains "/staging" or
  http.request.uri.path contains "/phpunit" or
  http.request.uri.path contains "/vendor/phpunit"
)
// Action: Block
// Note: Ensure your legitimate API paths (e.g., /api/v1/test) are not blocked
```

## 2. Rails Application Level

### Rack::Attack Configuration

This project provides a complete Rack::Attack configuration file covering all 25 attack patterns:

**File location**: `config/initializers/rack_attack.rb`

**Coverage**:
- ✅ Sensitive file access
- ✅ PHP/WordPress probing
- ✅ Admin panel probing
- ✅ Directory traversal
- ✅ SQL injection/XSS
- ✅ Command injection
- ✅ Laravel-specific attacks
- ✅ Symfony Profiler
- ✅ Spring Boot Actuator
- ✅ Struts vulnerabilities
- ✅ Nacos config center
- ✅ File manager vulnerabilities
- ✅ CI/CD config probing
- ✅ IDE config probing
- ✅ Node.js config files
- ✅ Search engine probing
- ✅ System file access
- ✅ Application config files
- ✅ Test/debug paths
- ✅ Database files
- ✅ Monitoring systems
- ✅ Known scanner User-Agent
- ✅ Rate limiting
- ✅ Automatic logging

**How to enable**:

The configuration file has all protection rules enabled by default. Just ensure Rack::Attack is in your Gemfile:

```ruby
# Gemfile
gem 'rack-attack', '~> 6.7'
```

Then restart the application.

**Custom configuration**:

If you need to adjust rules, edit `config/initializers/rack_attack.rb`. For example:

```ruby
# Allow specific IPs unrestricted
Rack::Attack.safelist('allow_trusted_ips') do |req|
  ['1.2.3.4', '5.6.7.8'].include?(req.ip)
end

# Adjust rate limiting
Rack::Attack.throttle('limit_requests_per_ip', limit: 500, period: 5.minutes) do |req|
  req.ip unless req.path.start_with?('/up', '/health')
end
```

**Monitoring and debugging**:

View blocked requests:

```bash
# View Rack::Attack logs
docker compose logs web | grep "Rack::Attack"

# View block statistics
docker compose logs web | grep "Blocked:" | wc -l

# View rate limit statistics
docker compose logs web | grep "Throttled:" | wc -l
```

### Rails Routes Constraint

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Explicitly define allowed routes
  namespace :api do
    namespace :v1 do
      resources :users
      resources :posts
      # ... other legitimate routes
    end
  end

  # Health check
  get '/up', to: 'rails/health#show', as: :rails_health_check

  # All other requests return 404 (don't use catch-all route)
  # Let Rails naturally return 404 to avoid accidentally exposing information

  # ❌ Don't use:
  # match '*path', to: 'application#not_found', via: :all
end
```

### Custom Middleware (Advanced)

```ruby
# app/middleware/path_security_filter.rb
class PathSecurityFilter
  BLOCKED_PATTERNS = [
    /\/\.env/i,
    /\/\.git/i,
    /\/config\//i,
    /\/logs?\//i,
    /\/backup/i,
    /aws.*\.(js|json|yml)/i,
    /credentials/i,
    /\.pem$/i,
    /\.key$/i,
    /docker-compose/i,
    /\.secrets\//i
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    if blocked_path?(request.path)
      # Log suspicious request
      Rails.logger.warn(
        "Blocked suspicious path: #{request.path} " \
        "from IP: #{request.ip} " \
        "User-Agent: #{request.user_agent}"
      )

      # Return 403
      return [
        403,
        { 'Content-Type' => 'application/json' },
        [{ error: 'Forbidden' }.to_json]
      ]
    end

    @app.call(env)
  end

  private

  def blocked_path?(path)
    BLOCKED_PATTERNS.any? { |pattern| path =~ pattern }
  end
end

# config/application.rb
config.middleware.insert_before 0, PathSecurityFilter
```

## 3. Infrastructure Level

### Docker Security Configuration

```dockerfile
# Dockerfile - Ensure sensitive files are not included
FROM ruby:3.4-alpine

# Use .dockerignore to exclude sensitive files
# (see .dockerignore example below)

# Don't include in image:
# - .env files
# - logs/
# - .git/
# - .secrets/
# - config/master.key

# Use Docker secrets instead of environment variables
# See docs/CONFIGURATION.md
```

### .dockerignore Verification

```
# .dockerignore - Ensure these files don't enter Docker image

# Environment files
.env
.env.*
!.env.example

# Secrets
.secrets/*
!.secrets/.gitkeep
!.secrets/README.md
!.secrets/*.example

# Git
.git
.gitignore

# Logs
/log/*
!/log/.keep

# Config
/config/master.key
/config/credentials/*.key

# Backups
/backup/
*.sql
*.dump

# AWS
aws-export.js
.aws/

# Docker files
docker-compose.yaml
docker-compose.yml
compose.yaml
compose.yml
Dockerfile
```

### File System Permissions

```bash
# In Docker container, ensure sensitive directories cannot be read
# docker-entrypoint.sh

# Remove potentially accidentally copied sensitive files
rm -f .env .env.local 2>/dev/null || true
rm -rf .git 2>/dev/null || true

# Set permissions
chmod 700 /run/secrets 2>/dev/null || true
chmod 600 /run/secrets/* 2>/dev/null || true

# Start application
exec "$@"
```

## 4. Monitoring and Alerting

### Set Up Alerts

```ruby
# app/middleware/security_logger.rb
class SecurityLogger
  ALERT_PATTERNS = [
    /\/\.env/i,
    /\/\.git/i,
    /\/backup/i,
    /credentials/i
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    if suspicious_path?(request.path)
      alert_security_team(request)
    end

    @app.call(env)
  end

  private

  def suspicious_path?(path)
    ALERT_PATTERNS.any? { |pattern| path =~ pattern }
  end

  def alert_security_team(request)
    # Log to Rails logs
    Rails.logger.error(
      "[SECURITY] Suspicious path access: #{request.path} " \
      "IP: #{request.ip} " \
      "User-Agent: #{request.user_agent} " \
      "Referer: #{request.referer}"
    )

    # Send to monitoring system (Datadog, Sentry, etc.)
    # Sentry.capture_message(
    #   "Suspicious path access",
    #   level: :warning,
    #   extra: {
    #     path: request.path,
    #     ip: request.ip,
    #     user_agent: request.user_agent
    #   }
    # )
  end
end
```

### Prometheus Metrics (Optional)

```ruby
# config/initializers/prometheus.rb
require 'prometheus/client'

prometheus = Prometheus::Client.registry

SUSPICIOUS_PATH_COUNTER = prometheus.counter(
  :suspicious_path_requests_total,
  docstring: 'Total number of suspicious path requests',
  labels: [:path_pattern]
)

# Use in middleware
# SUSPICIOUS_PATH_COUNTER.increment(labels: { path_pattern: 'env_file' })
```

## 5. Testing

### RSpec Tests

```ruby
# spec/requests/security_spec.rb
RSpec.describe 'Path Security', type: :request do
  describe 'sensitive paths' do
    it 'blocks .env file access' do
      get '/.env'
      expect(response).to have_http_status(:forbidden)
    end

    it 'blocks config directory access' do
      get '/config/database.yml'
      expect(response).to have_http_status(:forbidden)
    end

    it 'blocks log file access' do
      get '/logs/production.log'
      expect(response).to have_http_status(:forbidden)
    end

    it 'blocks AWS credential files' do
      get '/aws-export.js'
      expect(response).to have_http_status(:forbidden)
    end

    it 'blocks directory traversal' do
      get '/api/v1/users/../../../.env'
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'legitimate paths' do
    it 'allows API requests' do
      get '/api/v1/users'
      expect(response).not_to have_http_status(:forbidden)
    end
  end
end
```

## 6. Checklist

Pre-deployment check:

```markdown
□ Cloudflare WAF rules enabled
  □ Sensitive file path blocking rules
  □ Directory traversal blocking rules
  □ Scanner User-Agent blocking rules
  □ Rate limiting rules (404 requests)

□ Rails application protection
  □ Rack::Attack configured and enabled
  □ Sensitive path blocklist configured
  □ Routes explicitly defined, no catch-all route

□ Docker security
  □ .dockerignore includes all sensitive files
  □ Docker image doesn't contain .env, .git, logs/
  □ Docker secrets properly used

□ Monitoring
  □ Suspicious requests logged
  □ Alert rules set
  □ Regularly review security logs

□ Testing
  □ Security specs pass
  □ Manual test sensitive paths return 403
```

## 7. Emergency Response

When discovering large-scale scanning attacks:

```bash
# Cloudflare: Enable Under Attack Mode
# Dashboard > Security > Settings > Security Level > Under Attack Mode

# Temporarily block specific IP
# Dashboard > Security > WAF > Tools > IP Access Rules
# Add attacker IP, Action: Block

# Check Rails logs
docker compose logs web | grep -i "suspicious\|forbidden"

# Check attacked paths
docker compose logs web | grep "404\|403" | awk '{print $7}' | sort | uniq -c | sort -rn

# Analyze attacker IPs
docker compose logs web | grep "403" | awk '{print $1}' | sort | uniq -c | sort -rn
```

## 8. Fail2Ban Integration Assessment

### Conclusion: Not Recommended for Fail2Ban

Based on the current multi-layer defense architecture, **Fail2Ban is NOT needed**, for these reasons:

#### Existing Protection is Sufficient

| Feature | Cloudflare WAF | Rack::Attack | Fail2Ban | Assessment |
|------|----------------|--------------|----------|------|
| **Edge protection** | ✅ 99% attacks | ❌ | ❌ | CF already blocks most |
| **Rate Limiting** | ✅ | ✅ | ✅ | Already two layers |
| **IP blocking** | ✅ Automatic | ✅ Redis | ✅ iptables | Already two layers |
| **App-layer awareness** | ⚠️ Basic | ✅ Complete | ❌ | Rack::Attack better |
| **Docker friendly** | ✅ | ✅ | ⚠️ Needs special config | High deployment complexity |
| **Maintenance cost** | ✅ Low | ✅ Low | ⚠️ Medium-High | Needs extra maintenance |
| **Real-time effect** | ✅ | ✅ | ⚠️ Needs reload | Slower response |

#### Fail2Ban Limitations

1. **Docker environment complexity**
   ```yaml
   # Needs special Docker configuration
   services:
     fail2ban:
       image: crazymax/fail2ban
       network_mode: "host"  # ⚠️ Loses Docker network isolation
       cap_add:
         - NET_ADMIN         # ⚠️ Needs privileges
         - NET_RAW
       volumes:
         - /var/log:/var/log:ro  # ⚠️ Needs to mount host logs
   ```

2. **Duplicate functionality**
   - Cloudflare already blocks IPs at edge
   - Rack::Attack already blocks IPs at application layer
   - Fail2Ban would block again at firewall level (redundant)

3. **High maintenance cost**
   - Needs additional filter configuration
   - Needs to monitor Fail2Ban itself
   - Needs special permissions in Docker environment
   - Needs to update regex when log format changes

4. **No added value to existing protection**
   - Attacker IPs already blocked by Cloudflare
   - Direct IP access already restricted by Rack::Attack
   - Fail2Ban can only block IPs already intercepted by previous two layers

#### Recommended Defense Strategy

Use existing three-layer defense architecture:

```
Layer 1: Cloudflare WAF
  └─> Block 99% attacks
  └─> Automatic IP blocking
  └─> Rate limiting

Layer 2: Rack::Attack (Rails)
  └─> Application layer rules
  └─> Handle direct IP access
  └─> Redis-based IP blocking

Layer 3: Docker Security
  └─> .dockerignore
  └─> File permissions
  └─> Minimized image
```

### Special Cases: When to Consider Fail2Ban

Only consider Fail2Ban in these situations:

1. **Not using Cloudflare**
   - Directly exposing server to public internet
   - Need firewall-level IP blocking

2. **Non-web services**
   - SSH brute force protection
   - FTP/SMTP and other services

3. **Compliance requirements**
   - Some compliance standards require system-level IP blocking

### If You Still Want to Use Fail2Ban

If your scenario really needs Fail2Ban, here's the minimal configuration:

```yaml
# compose.yaml - Add Fail2Ban service
services:
  fail2ban:
    image: crazymax/fail2ban:latest
    container_name: fail2ban
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - ./fail2ban:/data
      - /var/log:/var/log:ro
    environment:
      TZ: Asia/Taipei
      F2B_LOG_LEVEL: INFO
    restart: unless-stopped
```

```ini
# fail2ban/jail.d/rails.conf
[rails-rack-attack]
enabled = true
port = http,https
filter = rails-rack-attack
logpath = /var/log/rails/production.log
maxretry = 10
findtime = 600
bantime = 3600
```

```ini
# fail2ban/filter.d/rails-rack-attack.conf
[Definition]
failregex = ^\[Rack::Attack\] Blocked:.* IP: <HOST>
ignoreregex =
```

But again: **For Rails applications using Cloudflare + Rack::Attack, Fail2Ban is not needed**.

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Cloudflare WAF Documentation](https://developers.cloudflare.com/waf/)
- [Rack::Attack Documentation](https://github.com/rack/rack-attack)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [Fail2Ban Documentation](https://www.fail2ban.org/) (for reference)
