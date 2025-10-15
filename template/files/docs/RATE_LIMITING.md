# Rate Limiting Best Practices Guide

API rate limiting is a critical mechanism for protecting applications from abuse, controlling costs, and maintaining service quality. This guide covers Rack::Attack best practices, strategy selection, and comprehensive examples.

## Table of Contents

- [Why Rate Limiting is Needed](#why-rate-limiting-is-needed)
- [Core Concepts](#core-concepts)
- [Strategy Selection](#strategy-selection)
- [Algorithm Comparison](#algorithm-comparison)
- [Redis Integration](#redis-integration)
- [Scenario Examples](#scenario-examples)
  - [Public API](#scenario-1-public-api)
  - [Private API (Authenticated Users)](#scenario-2-private-api-authenticated-users)
  - [Login Endpoint Protection](#scenario-3-login-endpoint-protection)
  - [Expensive Operations](#scenario-4-expensive-operations)
  - [WebSocket Connections](#scenario-5-websocket-connections)
  - [Subscription-based API](#scenario-6-subscription-based-api)
- [Cloudflare Integration](#cloudflare-integration)
- [Testing Methods](#testing-methods)
- [Monitoring and Alerting](#monitoring-and-alerting)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [Performance Optimization](#performance-optimization)

---

## Why Rate Limiting is Needed

### Defending Against Attacks

**DDoS (Distributed Denial of Service):**
```
Before attack:
├─ Normal users: 100 req/sec
└─ Server: CPU 30%, running normally

During attack (without rate limiting):
├─ Botnet: 10,000 req/sec
├─ Normal users: Degraded, cannot access
└─ Server: CPU 100%, crashed

During attack (with rate limiting):
├─ Botnet: Limited to 100 req/sec per IP
├─ Normal users: Service normal
└─ Server: CPU 40%, running stable
```

**Credential Stuffing:**
```
# Attacker tries username/password combinations from data breaches
POST /api/v1/login
{
  "email": "user1@example.com",
  "password": "leaked_password_1"
}
POST /api/v1/login
{
  "email": "user2@example.com",
  "password": "leaked_password_2"
}
...
# 1000 attempts/minute, trying all combinations

# With rate limiting:
# 6th request → 429 Too Many Requests
# Attacker needs thousands of IPs to continue (cost increases significantly)
```

**Web Scraping:**
```
# Malicious crawler attempts to steal data
GET /api/products/1
GET /api/products/2
GET /api/products/3
...
GET /api/products/100000

# With rate limiting:
# Limited to 100 req/min
# 100,000 records takes 16+ hours (instead of 10 minutes)
# Crawler cost increases significantly, most will give up
```

### Cost Control

**Cloud Service Costs:**
```
Scenario: Using AWS API Gateway + Lambda

Without rate limiting:
├─ Malicious user: 1,000,000 requests/day
├─ Lambda execution: $0.20 per 1M requests
└─ Cost: $0.20/day × 30 = $6/month

# Seems minor, but if there are 10 malicious users:
# $6 × 10 = $60/month wasted

With rate limiting:
├─ Normal users: 100,000 requests/day
├─ Malicious users: Limited
└─ Cost: $0.02/day × 30 = $0.60/month

Savings: $59.40/month (99% cost reduction)
```

**Database Load:**
```
# Expensive query
GET /api/reports/monthly?year=2024

# Query time: 5 seconds
# CPU usage: 80%

Without rate limiting:
├─ 10 concurrent user requests
├─ Database: 800% CPU (crashed)
└─ RDS cost: Need to upgrade to larger instance

With rate limiting:
├─ Limited to 1 req/min per user
├─ Database: Stable
└─ RDS cost: Maintain original instance size
```

### Service Quality Guarantee

**Prevent Single User Monopolizing Resources:**

```ruby
# Scenario: Report generation service

# User A (malicious or programming error):
100.times { generate_report }  # Generate 100 reports simultaneously

# Without rate limiting:
# → Occupies all workers
# → User B, C, D requests are blocked
# → Everyone's experience degrades

# With rate limiting:
# User A: Limited to 5 reports/hour
# → User B, C, D can use normally
# → Fair usage for everyone
```

---

## Core Concepts

### How Rack::Attack Works

```
HTTP Request
     ↓
[Rack::Attack Middleware]
     ↓
Check Safelist ─→ Pass ─→ Rails Application
     ↓
Check Blocklist ─→ Reject ─→ 429 Response
     ↓
Check Throttle ─→ Limit exceeded ─→ 429 Response
     ↓           ↓
          Limit not exceeded
                ↓
         Rails Application
```

### Three Mechanisms

#### 1. Safelist (Whitelist)

**Purpose:** Always allow specific sources

```ruby
# config/initializers/rack_attack.rb
Rack::Attack.safelist('allow-localhost') do |req|
  req.ip == '127.0.0.1' || req.ip == '::1'
end

Rack::Attack.safelist('allow-internal-network') do |req|
  # Internal network not limited
  req.ip =~ /^10\./
end

Rack::Attack.safelist('allow-monitoring') do |req|
  # Uptime monitoring services
  req.path == '/up' && req.get?
end
```

#### 2. Blocklist (Blacklist)

**Purpose:** Completely block known malicious sources

```ruby
Rack::Attack.blocklist('block-bad-ips') do |req|
  # Read blocklist from database or Redis
  REDIS_CACHE.with { |r| r.sismember('blocked_ips', req.ip) }
end

Rack::Attack.blocklist('block-malicious-user-agents') do |req|
  # Block known malicious crawlers
  req.user_agent =~ /BadBot|Scraper|Harvester/i
end

Rack::Attack.blocklist('block-sql-injection-attempts') do |req|
  # Block SQL injection attempts
  req.query_string =~ /UNION.*SELECT/i || req.path =~ /';.*DROP.*TABLE/i
end
```

#### 3. Throttle (Rate Limiting)

**Purpose:** Limit request frequency

```ruby
# Basic throttle
Rack::Attack.throttle('req/ip', limit: 100, period: 1.minute) do |req|
  req.ip  # discriminator (identifier)
end

# The discriminator return value determines who is limited
# Same discriminator = share the same counter
```

---

## Strategy Selection

### 1. IP-based Rate Limiting

**Advantages:**
- ✅ Simple to implement
- ✅ No authentication required
- ✅ Protects anonymous endpoints

**Disadvantages:**
- ❌ Multiple users behind NAT/Proxy share same IP
- ❌ Attackers can use multiple IPs (distributed attack)
- ❌ VPN/Tor easily bypasses

**Applicable Scenarios:**
- Public read-only API
- Login pages (cannot identify users before login)
- Static content services

**Example:**
```ruby
# Global IP limit
Rack::Attack.throttle('req/ip', limit: 300, period: 5.minutes) do |req|
  req.ip
end
```

### 2. User-based Rate Limiting

**Advantages:**
- ✅ Precise control (each user counts independently)
- ✅ Supports subscription tiers (different limits for different tiers)
- ✅ Cannot bypass by changing IP

**Disadvantages:**
- ❌ Requires user to be logged in
- ❌ Cannot protect login endpoint itself
- ❌ Needs additional logic (extract user ID from token/session)

**Applicable Scenarios:**
- Private API (requires API key)
- Authenticated user operations
- SaaS subscription services

**Example:**
```ruby
# Limit by user ID
Rack::Attack.throttle('req/user', limit: 1000, period: 1.hour) do |req|
  if req.env['warden'].user  # Devise
    req.env['warden'].user.id
  end
end
```

### 3. Endpoint-based Rate Limiting

**Advantages:**
- ✅ Targeted protection for expensive operations
- ✅ Different strategies for different endpoints
- ✅ High flexibility

**Disadvantages:**
- ❌ Complex configuration
- ❌ Need to maintain multiple rules

**Applicable Scenarios:**
- Resource-intensive endpoints (reports, exports)
- Write operations (POST/PUT/DELETE)
- Sensitive endpoints (password reset)

**Example:**
```ruby
# File upload limit (stricter)
Rack::Attack.throttle('uploads/ip', limit: 5, period: 1.hour) do |req|
  req.ip if req.path =~ /\/uploads$/ && req.post?
end

# Search limit (prevent regex DoS)
Rack::Attack.throttle('search/ip', limit: 20, period: 1.minute) do |req|
  req.ip if req.path =~ /\/search$/
end
```

### Strategy Comparison Table

| Strategy | Simplicity | Precision | Applicable Scenarios | Bypass Difficulty |
|------|--------|--------|---------|---------|
| IP-based | ⭐⭐⭐ | ⭐ | Public API, anonymous endpoints | Low (change IP) |
| User-based | ⭐⭐ | ⭐⭐⭐ | Private API, authenticated users | High (need multiple accounts) |
| Endpoint-based | ⭐ | ⭐⭐⭐ | Specific endpoint protection | Medium (depends on implementation) |
| Hybrid (mixed) | ⭐ | ⭐⭐⭐ | Production environment | High |

**Recommendation: Hybrid Approach**

```ruby
# Global IP limit (loose, prevent brute force)
Rack::Attack.throttle('global/ip', limit: 300, period: 5.minutes) do |req|
  req.ip
end

# Authenticated user limit (medium, based on subscription plan)
Rack::Attack.throttle('api/user', limit: 1000, period: 1.hour) do |req|
  req.env['warden'].user&.id if authenticated?(req)
end

# Sensitive endpoint limit (strict)
Rack::Attack.throttle('login/ip', limit: 5, period: 20.seconds) do |req|
  req.ip if req.path == '/login' && req.post?
end
```

---

## Algorithm Comparison

### 1. Fixed Window

**Rack::Attack default algorithm**

**Principle:**
```
Time: 0s───────30s───────60s───────90s
      └──Window 1─┘└──Window 2─┘└──Window 3─┘

Limit: 10 requests/minute

Requests:
00:00 → 1  ✅
00:10 → 2  ✅
...
00:50 → 10 ✅
00:55 → 11 ❌ Blocked
01:00 → 1  ✅ (new window, counter reset)
```

**Advantages:**
- ✅ Simple implementation
- ✅ Low Redis memory usage (single counter)
- ✅ Best performance

**Disadvantages:**
- ❌ Window boundary issue (burst traffic)

**Problem Example:**
```
Limit: 100 req/min

00:59 → 100 requests ✅
01:00 → 100 requests ✅ (new window)

Actually received 200 requests within 1 minute (00:59-01:01)
→ 2x the expected limit!
```

**Applicable Scenarios:**
- Most situations (performance priority)
- Applications with steady traffic

### 2. Sliding Window

**Requires additional implementation or gem**

**Principle:**
```
Time: Now-60s ←───────────→ Now
      └───────Rolling Window───────┘

Limit: 10 requests/minute

Check method:
- Calculate all requests within "60 seconds from now"
- Each request has a precise timestamp
```

**Advantages:**
- ✅ No window boundary issue
- ✅ More precise limits
- ✅ Prevents burst traffic

**Disadvantages:**
- ❌ Higher Redis memory usage (need to store each request's timestamp)
- ❌ Higher computation cost
- ❌ Rack::Attack doesn't support directly (need custom implementation)

**Implementation Example:**
```ruby
# Using Redis Sorted Set
Rack::Attack.throttle('sliding/ip', limit: 100, period: 1.minute) do |req|
  key = "rack-attack:sliding:#{req.ip}"
  now = Time.now.to_f
  window = 60  # seconds

  REDIS_CACHE.with do |redis|
    # Remove old records beyond window
    redis.zremrangebyscore(key, 0, now - window)

    # Count requests within current window
    count = redis.zcard(key)

    if count < 100
      # Add this request
      redis.zadd(key, now, "#{now}:#{rand}")
      redis.expire(key, window * 2)
      nil  # Don't limit
    else
      req.ip  # Limit
    end
  end
end
```

**Applicable Scenarios:**
- Need precise control
- High-value API
- Strict SLA requirements

### 3. Token Bucket

**Requires additional implementation**

**Principle:**
```
Bucket (capacity 100)
├─ Initial: 100 tokens
├─ Refill rate: 2 tokens/second (max 100)
└─ Each request consumes: 1 token

Allows "burst traffic":
- Can use all 100 tokens in short period
- But long-term average rate is still 2 req/sec
```

**Advantages:**
- ✅ Allows reasonable burst traffic
- ✅ Smooth long-term rate
- ✅ Better user experience

**Disadvantages:**
- ❌ More complex implementation
- ❌ Rack::Attack doesn't support directly

**Applicable Scenarios:**
- Need to allow short-term bursts
- WebSocket connections
- Batch operations

### 4. Leaky Bucket

**Requires additional implementation**

**Principle:**
```
Bucket (capacity 100)
├─ Requests enter bucket (queue)
├─ Fixed rate outflow: 2 req/sec
└─ Exceeds capacity → overflow → reject

Forces "smooth traffic":
- Even with burst, can only process at fixed rate
```

**Advantages:**
- ✅ Smoothest traffic
- ✅ Predictable backend load

**Disadvantages:**
- ❌ Higher latency (needs queue)
- ❌ Complex implementation

**Applicable Scenarios:**
- Backend cannot handle bursts
- Need absolutely smooth traffic

### Algorithm Selection Recommendations

```ruby
# Most situations: Fixed Window (Rack::Attack default)
Rack::Attack.throttle('default', limit: 100, period: 1.minute) do |req|
  req.ip
end

# Need precise control: Implement Sliding Window
# (for high-value API)

# Need to allow bursts: Implement Token Bucket
# (for WebSocket, batch operations)

# Need absolute smooth: Implement Leaky Bucket
# (for backends that cannot handle bursts)
```

**Recommendation:**
- ✅ Use **Fixed Window** (Rack::Attack default) in 99% of situations
- ✅ Best cost-performance ratio, best performance
- ⚠️ Only consider other algorithms when absolute precision is needed

---

## Redis Integration

### Why Redis is Needed?

**Problem: Single-machine memory store**

```ruby
# Rack::Attack uses Rails.cache by default
# If cache is memory store:

# Server 1: Sees IP 1.2.3.4 has 50 requests
# Server 2: Sees IP 1.2.3.4 has 50 requests
# Server 3: Sees IP 1.2.3.4 has 50 requests

# Actually IP 1.2.3.4 sent 150 requests
# But each server thinks it hasn't exceeded 100 limit → ineffective!
```

**Solution: Use Redis (shared state)**

```ruby
# All servers share the same Redis
# Redis: IP 1.2.3.4 = 150 requests
# → All servers see same counter → correctly blocks
```

### Configure Rack::Attack to Use Redis

**This template is already configured!**

```ruby
# gem/redis.rb already sets Rails.cache to use redis_cache
Rails.application.config.cache_store = :redis_cache_store, {
  url: cache_url,
  # ...
}

# Rack::Attack automatically uses Rails.cache
# No additional configuration needed!
```

### Verify Redis is Being Used

```bash
# Trigger rate limit
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"wrong"}' \
  -w "\nHTTP Status: %{http_code}\n"

# After 6 attempts should see 429

# Check Redis
docker exec redis_cache redis-cli KEYS "rack::attack:*"

# Should see something like:
# rack::attack:logins/ip:192.168.1.1
```

### Redis Key Naming Convention

```
Rack::Attack Redis keys:
rack::attack:{name}:{discriminator}

Examples:
rack::attack:req/ip:1.2.3.4
rack::attack:logins/email:user@example.com
rack::attack:api/user:123
```

### Memory Usage Estimation

```ruby
# Each throttle counter:
# Key: ~50 bytes
# Value: 8 bytes (integer)
# TTL metadata: ~20 bytes
# Total: ~78 bytes per counter

# Example: 10,000 different IPs
# 10,000 × 78 bytes = 780 KB

# redis_cache has 1GB, more than enough
```

---

## Scenario Examples

### Scenario 1: Public API

**Requirements:**
- Anyone can access
- Prevent single IP brute force requests
- Loose limits (don't affect normal usage)

**Strategy: IP-based throttling**

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Automatically uses Rails.cache (redis_cache)
  # No additional configuration needed

  # === Safelists ===

  # Allow localhost (development/test)
  safelist('allow-localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1'
  end

  # Allow health check endpoint (doesn't count towards limit)
  safelist('allow-healthcheck') do |req|
    req.path == '/up' && req.get?
  end

  # === Throttles ===

  # Global limit: 300 requests per 5 minutes per IP
  # Average = 60 req/min = 1 req/sec
  # Suitable for most read-only API
  throttle('api/ip', limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?('/admin')  # Handle admin separately
  end

  # Write operation limit (stricter)
  throttle('writes/ip', limit: 50, period: 5.minutes) do |req|
    req.ip if %w[POST PUT PATCH DELETE].include?(req.request_method)
  end

  # === Custom Response ===

  self.throttled_responder = lambda do |env|
    retry_after = (env['rack.attack.match_data'] || {})[:period]
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s
      },
      [{ error: 'Rate limit exceeded. Try again later.' }.to_json]
    ]
  end
end
```

**Testing:**

```bash
# Normal requests
for i in {1..300}; do
  curl -s http://localhost:3000/api/v1/products > /dev/null
  echo "Request $i sent"
done

# 301st request should receive 429
curl -v http://localhost:3000/api/v1/products

# Output:
# < HTTP/1.1 429 Too Many Requests
# < Retry-After: 300
# {"error":"Rate limit exceeded. Try again later."}
```

---

### Scenario 2: Private API (Authenticated Users)

**Requirements:**
- Requires API key or JWT token
- Different users count independently
- Supports subscription tiers (different limits for different tiers)

**Strategy: User-based throttling**

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # === Helper Methods ===

  def self.authenticated_user_id(req)
    # Method 1: Use Devise/Warden
    req.env['warden']&.user&.id

    # Method 2: Use JWT token
    # token = req.env['HTTP_AUTHORIZATION']&.sub(/^Bearer /, '')
    # decoded = JWT.decode(token, Rails.application.secret_key_base)[0]
    # decoded['user_id']
  rescue
    nil
  end

  def self.user_tier(user_id)
    # Get user tier from Redis cache
    REDIS_SESSION.with do |redis|
      tier = redis.get("user:#{user_id}:tier")
      tier || 'free'  # Default free tier
    end
  rescue
    'free'
  end

  # === Throttles ===

  # Free tier: 100 requests/hour
  throttle('api/free', limit: 100, period: 1.hour) do |req|
    user_id = authenticated_user_id(req)
    user_id if user_id && user_tier(user_id) == 'free'
  end

  # Pro tier: 1,000 requests/hour
  throttle('api/pro', limit: 1000, period: 1.hour) do |req|
    user_id = authenticated_user_id(req)
    user_id if user_id && user_tier(user_id) == 'pro'
  end

  # Enterprise tier: 10,000 requests/hour
  throttle('api/enterprise', limit: 10_000, period: 1.hour) do |req|
    user_id = authenticated_user_id(req)
    user_id if user_id && user_tier(user_id) == 'enterprise'
  end

  # Unauthenticated users: Very strict
  throttle('api/unauthenticated', limit: 10, period: 1.hour) do |req|
    req.ip unless authenticated_user_id(req)
  end

  # === Custom Response (includes remaining quota) ===

  self.throttled_responder = lambda do |env|
    match_data = env['rack.attack.match_data']
    now = Time.now.to_i
    period = match_data[:period]
    limit = match_data[:limit]

    # Calculate reset time
    reset_time = (now / period + 1) * period

    [
      429,
      {
        'Content-Type' => 'application/json',
        'X-RateLimit-Limit' => limit.to_s,
        'X-RateLimit-Remaining' => '0',
        'X-RateLimit-Reset' => reset_time.to_s,
        'Retry-After' => (reset_time - now).to_s
      },
      [{
        error: 'Rate limit exceeded',
        message: 'You have exceeded your API quota',
        reset_at: Time.at(reset_time).iso8601
      }.to_json]
    ]
  end
end

# === Add Rate Limit Headers in ApplicationController ===
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  after_action :set_rate_limit_headers

  private

  def set_rate_limit_headers
    # Get match_data from Rack::Attack
    match_data = request.env['rack.attack.match_data']
    return unless match_data

    response.set_header('X-RateLimit-Limit', match_data[:limit].to_s)
    response.set_header('X-RateLimit-Remaining', match_data[:count].to_s)

    # Reset time
    now = Time.now.to_i
    period = match_data[:period]
    reset_time = (now / period + 1) * period
    response.set_header('X-RateLimit-Reset', reset_time.to_s)
  end
end
```

**API Response Example:**

```http
# Normal request
GET /api/v1/products HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

HTTP/1.1 200 OK
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 842
X-RateLimit-Reset: 1703001600
```

```http
# Exceeded limit
GET /api/v1/products HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1703001600
Retry-After: 3600

{
  "error": "Rate limit exceeded",
  "message": "You have exceeded your API quota",
  "reset_at": "2024-12-20T10:00:00Z"
}
```

---

### Scenario 3: Login Endpoint Protection

**Requirements:**
- Prevent brute force
- Prevent credential stuffing
- Prevent distributed attacks

**Strategy: Multi-layer protection (IP + Email)**

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # === Protection Layer 1: IP-based ===

  # Per IP limit (prevent single source brute force)
  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/login' && req.post?
      req.ip
    end
  end

  # === Protection Layer 2: Email-based ===

  # Per email limit (prevent distributed attack on same account)
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/login' && req.post?
      # Get email from request body
      email = req.params['email'].to_s.downcase.strip
      email.presence
    end
  end

  # === Protection Layer 3: Global login limit ===

  # Prevent massive login attempts (regardless of success or failure)
  throttle('logins/global', limit: 100, period: 1.minute) do |req|
    'logins' if req.path == '/api/v1/login' && req.post?
  end

  # === Exponential Backoff (optional) ===

  # Increase block time after multiple failures
  Rack::Attack.blocklist('login-failures/ip') do |req|
    if req.path == '/api/v1/login' && req.post?
      key = "login-failures:#{req.ip}"
      failures = REDIS_CACHE.with { |r| r.get(key).to_i }

      # 5 failures → block 1 minute
      # 10 failures → block 10 minutes
      # 20 failures → block 1 hour
      case failures
      when 5..9
        REDIS_CACHE.with { |r| r.setex("block:#{req.ip}", 60, 1) }
        true
      when 10..19
        REDIS_CACHE.with { |r| r.setex("block:#{req.ip}", 600, 1) }
        true
      when 20..Float::INFINITY
        REDIS_CACHE.with { |r| r.setex("block:#{req.ip}", 3600, 1) }
        true
      else
        false
      end
    end
  end

  # === Custom Response (provide more information) ===

  self.throttled_responder = lambda do |env|
    match_type = env['rack.attack.matched']

    case match_type
    when 'logins/ip'
      message = 'Too many login attempts from your IP. Please wait 20 seconds.'
    when 'logins/email'
      message = 'Too many login attempts for this account. Please wait 20 seconds.'
    when 'logins/global'
      message = 'System is experiencing high login traffic. Please try again later.'
    else
      message = 'Rate limit exceeded.'
    end

    [
      429,
      { 'Content-Type' => 'application/json', 'Retry-After' => '20' },
      [{ error: message }.to_json]
    ]
  end
end

# === Record failure count in SessionsController ===
# app/controllers/api/v1/sessions_controller.rb
class Api::V1::SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      # Success → clear failure count
      clear_login_failures(request.ip)

      render json: { token: generate_token(user) }
    else
      # Failure → increment count
      increment_login_failures(request.ip)

      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end

  private

  def increment_login_failures(ip)
    key = "login-failures:#{ip}"
    REDIS_CACHE.with do |redis|
      redis.incr(key)
      redis.expire(key, 1.hour)  # Auto-clear after 1 hour
    end
  end

  def clear_login_failures(ip)
    key = "login-failures:#{ip}"
    REDIS_CACHE.with { |redis| redis.del(key) }
  end
end
```

**Effect:**

```bash
# Normal user (correct password)
curl -X POST http://localhost:3000/api/v1/login \
  -d '{"email":"user@example.com","password":"correct_password"}'
# → 200 OK

# Attacker (brute force)
for i in {1..5}; do
  curl -X POST http://localhost:3000/api/v1/login \
    -d '{"email":"victim@example.com","password":"wrong_'$i'"}'
done

# 6th attempt
curl -X POST http://localhost:3000/api/v1/login \
  -d '{"email":"victim@example.com","password":"wrong_6"}'
# → 429 Too Many Requests
# → "Too many login attempts for this account. Please wait 20 seconds."
```

---

### Scenario 4: Expensive Operations

**Requirements:**
- File uploads, report generation, data exports (resource-intensive operations)
- Stricter limits (avoid occupying all workers)
- Support queuing mechanism

**Strategy: Strict endpoint-specific throttling**

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # === File Upload Limits ===

  # Per user: 5 uploads/hour
  throttle('uploads/user', limit: 5, period: 1.hour) do |req|
    if req.path =~ /\/api\/.*\/uploads$/ && req.post?
      user_id = authenticated_user_id(req)
      user_id if user_id
    end
  end

  # Global upload limit: 100 times/minute (protect server)
  throttle('uploads/global', limit: 100, period: 1.minute) do |req|
    'uploads' if req.path =~ /\/api\/.*\/uploads$/ && req.post?
  end

  # === Report Generation Limits ===

  # Per user: 1 report/5 minutes (reports are expensive)
  throttle('reports/user', limit: 1, period: 5.minutes) do |req|
    if req.path =~ /\/api\/.*\/reports$/ && req.post?
      user_id = authenticated_user_id(req)
      user_id if user_id
    end
  end

  # === Data Export Limits ===

  # Per user: 3 exports/day
  throttle('exports/user', limit: 3, period: 24.hours) do |req|
    if req.path =~ /\/api\/.*\/export$/ && req.get?
      user_id = authenticated_user_id(req)
      user_id if user_id
    end
  end

  # === Search Limits (prevent Regex DoS) ===

  # Per IP: 30 searches/minute
  throttle('search/ip', limit: 30, period: 1.minute) do |req|
    req.ip if req.path =~ /\/api\/.*\/search$/
  end

  # === Custom Response (suggest using background job) ===

  self.throttled_responder = lambda do |env|
    match_type = env['rack.attack.matched']

    message = case match_type
              when /uploads/
                'Upload quota exceeded. Maximum 5 uploads per hour.'
              when /reports/
                'Report generation limit reached. Please wait 5 minutes.'
              when /exports/
                'Export quota exceeded. Maximum 3 exports per day.'
              when /search/
                'Search rate limit exceeded. Please wait 1 minute.'
              else
                'Rate limit exceeded.'
              end

    [
      429,
      { 'Content-Type' => 'application/json' },
      [{
        error: message,
        suggestion: 'Consider using background jobs for expensive operations'
      }.to_json]
    ]
  end
end

# === Controller Implementation: Convert to Background Job ===
# app/controllers/api/v1/reports_controller.rb
class Api::V1::ReportsController < ApplicationController
  def create
    # Don't generate report synchronously (blocks web worker)
    # Use background job
    job = ReportGenerationJob.perform_later(
      user_id: current_user.id,
      params: report_params
    )

    render json: {
      message: 'Report generation started',
      job_id: job.job_id,
      status_url: api_v1_report_status_url(job_id: job.job_id)
    }, status: :accepted
  end

  def status
    # Query job status
    job_status = check_job_status(params[:job_id])

    if job_status[:completed]
      render json: {
        status: 'completed',
        download_url: job_status[:download_url]
      }
    else
      render json: {
        status: 'processing',
        progress: job_status[:progress]
      }
    end
  end
end
```

**Recommended Architecture:**

```
HTTP Request → Rack::Attack → Rails Controller
                                    ↓
                              Enqueue Background Job
                                    ↓
                              Return 202 Accepted + Job ID

User polls status endpoint → Job completed? → Download URL
```

---

### Scenario 5: WebSocket Connections

**Requirements:**
- Limit concurrent connections
- Limit message frequency
- Prevent connection flooding

**Strategy: Connection limit + Message limit**

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # === WebSocket Connection Establishment Limits ===

  # Per IP: 10 concurrent connections
  # Note: Need custom counter (Rack::Attack default is request count)
  throttle('cable/connect/ip', limit: 10, period: 1.minute) do |req|
    req.ip if req.path == '/cable' && req.env['HTTP_UPGRADE'] == 'websocket'
  end

  # Per user: 5 concurrent connections
  throttle('cable/connect/user', limit: 5, period: 1.minute) do |req|
    if req.path == '/cable' && req.env['HTTP_UPGRADE'] == 'websocket'
      user_id = authenticated_user_id(req)
      user_id if user_id
    end
  end
end

# === Message Limits within ActionCable Connection ===
# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user

      # Check connection count limit
      if connection_count_exceeded?
        reject_unauthorized_connection
      end
    end

    private

    def find_verified_user
      # Verify user from cookies or query params
      if verified_user = User.find_by(id: cookies.encrypted[:user_id])
        verified_user
      else
        reject_unauthorized_connection
      end
    end

    def connection_count_exceeded?
      key = "cable:connections:#{current_user.id}"
      count = REDIS_CABLE.with { |r| r.scard(key) }
      count >= 5  # Max 5 connections
    end
  end
end

# === Limit Message Frequency within Channel ===
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_#{params[:room_id]}"

    # Record connection
    REDIS_CABLE.with do |redis|
      redis.sadd("cable:connections:#{current_user.id}", connection.connection_identifier)
      redis.expire("cable:connections:#{current_user.id}", 1.hour)
    end
  end

  def unsubscribed
    # Remove connection record
    REDIS_CABLE.with do |redis|
      redis.srem("cable:connections:#{current_user.id}", connection.connection_identifier)
    end
  end

  def send_message(data)
    # Message frequency limit: 10 messages/minute per user
    key = "cable:messages:#{current_user.id}"
    count = REDIS_CABLE.with do |redis|
      redis.incr(key)
      redis.expire(key, 60) if redis.ttl(key) < 0
      redis.get(key).to_i
    end

    if count > 10
      transmit({
        error: 'Message rate limit exceeded. Please slow down.'
      })
      return
    end

    # Send message
    ChatMessage.create!(
      user: current_user,
      room_id: params[:room_id],
      content: data['message']
    )

    ActionCable.server.broadcast("chat_#{params[:room_id]}", {
      user: current_user.name,
      message: data['message'],
      timestamp: Time.now.iso8601
    })
  end
end
```

**Monitor Connection Count:**

```ruby
# app/controllers/admin/websocket_controller.rb
class Admin::WebsocketController < ApplicationController
  def stats
    # Total connections
    total_connections = Redis.new(url: ENV['REDIS_CABLE_URL']).info['connected_clients']

    # Connections per user
    user_connections = User.pluck(:id).map do |user_id|
      key = "cable:connections:#{user_id}"
      count = REDIS_CABLE.with { |r| r.scard(key) }
      { user_id: user_id, connections: count } if count > 0
    end.compact

    render json: {
      total_connections: total_connections,
      user_connections: user_connections
    }
  end
end
```

---

### Scenario 6: Subscription-based API

**Requirements:**
- Free / Pro / Enterprise three tiers
- Different limits for different tiers
- Display remaining quota in real-time
- Support quota reset

**Strategy: Dynamic limits based on user tier**

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # === Tier Configurations ===

  TIER_LIMITS = {
    'free' => {
      hourly: 100,
      daily: 1000,
      concurrent: 1
    },
    'pro' => {
      hourly: 1000,
      daily: 20_000,
      concurrent: 5
    },
    'enterprise' => {
      hourly: 10_000,
      daily: Float::INFINITY,
      concurrent: 50
    }
  }.freeze

  # === Helper Methods ===

  def self.user_tier(user_id)
    # Get tier from database or Redis cache
    Rails.cache.fetch("user:#{user_id}:tier", expires_in: 5.minutes) do
      User.find(user_id).subscription_tier
    end
  rescue
    'free'
  end

  def self.tier_limit(tier, period)
    TIER_LIMITS.dig(tier, period) || 0
  end

  # === Throttles ===

  # Hourly limit per tier
  throttle('api/hourly/free', limit: proc { tier_limit('free', :hourly) }, period: 1.hour) do |req|
    user_id = authenticated_user_id(req)
    user_id if user_id && user_tier(user_id) == 'free'
  end

  throttle('api/hourly/pro', limit: proc { tier_limit('pro', :hourly) }, period: 1.hour) do |req|
    user_id = authenticated_user_id(req)
    user_id if user_id && user_tier(user_id) == 'pro'
  end

  throttle('api/hourly/enterprise', limit: proc { tier_limit('enterprise', :hourly) }, period: 1.hour) do |req|
    user_id = authenticated_user_id(req)
    user_id if user_id && user_tier(user_id) == 'enterprise'
  end

  # Daily limit per tier
  throttle('api/daily/free', limit: proc { tier_limit('free', :daily) }, period: 24.hours) do |req|
    user_id = authenticated_user_id(req)
    user_id if user_id && user_tier(user_id) == 'free'
  end

  throttle('api/daily/pro', limit: proc { tier_limit('pro', :daily) }, period: 24.hours) do |req|
    user_id = authenticated_user_id(req)
    user_id if user_id && user_tier(user_id) == 'pro'
  end

  # Enterprise has no daily limit

  # === Custom Response with Tier Info ===

  self.throttled_responder = lambda do |env|
    req = Rack::Request.new(env)
    user_id = authenticated_user_id(req)
    tier = user_tier(user_id)
    match_data = env['rack.attack.match_data']

    # Calculate reset time
    now = Time.now.to_i
    period = match_data[:period]
    reset_time = (now / period + 1) * period

    [
      429,
      {
        'Content-Type' => 'application/json',
        'X-RateLimit-Limit' => match_data[:limit].to_s,
        'X-RateLimit-Remaining' => '0',
        'X-RateLimit-Reset' => reset_time.to_s,
        'X-RateLimit-Tier' => tier,
        'Retry-After' => (reset_time - now).to_s
      },
      [{
        error: 'API quota exceeded',
        tier: tier,
        limit: match_data[:limit],
        reset_at: Time.at(reset_time).iso8601,
        upgrade_url: tier == 'free' ? 'https://example.com/upgrade' : nil
      }.to_json]
    ]
  end
end

# === ApplicationController: Response headers ===
class ApplicationController < ActionController::API
  after_action :set_rate_limit_headers

  private

  def set_rate_limit_headers
    return unless current_user

    tier = current_user.subscription_tier

    # Hourly limit
    hourly_key = "rack::attack:api/hourly/#{tier}:#{current_user.id}"
    hourly_count = Rails.cache.read(hourly_key) || 0
    hourly_limit = Rack::Attack::TIER_LIMITS.dig(tier, :hourly)

    # Daily limit
    daily_key = "rack::attack:api/daily/#{tier}:#{current_user.id}"
    daily_count = Rails.cache.read(daily_key) || 0
    daily_limit = Rack::Attack::TIER_LIMITS.dig(tier, :daily)

    # Set headers
    response.set_header('X-RateLimit-Tier', tier)
    response.set_header('X-RateLimit-Hourly-Limit', hourly_limit.to_s)
    response.set_header('X-RateLimit-Hourly-Remaining', (hourly_limit - hourly_count).to_s)
    response.set_header('X-RateLimit-Daily-Limit', daily_limit.to_s)
    response.set_header('X-RateLimit-Daily-Remaining', (daily_limit - daily_count).to_s)
  end
end

# === Dashboard Controller: Display Usage ===
class Api::V1::DashboardController < ApplicationController
  def quota
    tier = current_user.subscription_tier
    limits = Rack::Attack::TIER_LIMITS[tier]

    # Get usage from Redis
    hourly_key = "rack::attack:api/hourly/#{tier}:#{current_user.id}"
    daily_key = "rack::attack:api/daily/#{tier}:#{current_user.id}"

    hourly_used = Rails.cache.read(hourly_key) || 0
    daily_used = Rails.cache.read(daily_key) || 0

    render json: {
      tier: tier,
      hourly: {
        limit: limits[:hourly],
        used: hourly_used,
        remaining: limits[:hourly] - hourly_used,
        reset_at: (Time.now.beginning_of_hour + 1.hour).iso8601
      },
      daily: {
        limit: limits[:daily],
        used: daily_used,
        remaining: limits[:daily] == Float::INFINITY ? 'unlimited' : limits[:daily] - daily_used,
        reset_at: (Time.now.beginning_of_day + 1.day).iso8601
      }
    }
  end
end
```

**API Response Example:**

```http
GET /api/v1/products HTTP/1.1
Authorization: Bearer <token>

HTTP/1.1 200 OK
X-RateLimit-Tier: pro
X-RateLimit-Hourly-Limit: 1000
X-RateLimit-Hourly-Remaining: 842
X-RateLimit-Daily-Limit: 20000
X-RateLimit-Daily-Remaining: 15234
```

```http
GET /api/v1/dashboard/quota HTTP/1.1
Authorization: Bearer <token>

HTTP/1.1 200 OK

{
  "tier": "pro",
  "hourly": {
    "limit": 1000,
    "used": 158,
    "remaining": 842,
    "reset_at": "2024-12-20T11:00:00Z"
  },
  "daily": {
    "limit": 20000,
    "used": 4766,
    "remaining": 15234,
    "reset_at": "2024-12-21T00:00:00Z"
  }
}
```

---

## Cloudflare Integration

### Dual-Layer Protection Architecture

```
Internet
    ↓
[Cloudflare WAF + Rate Limiting]  ← Layer 1: Edge protection
    ↓ (only legitimate traffic)
[Cloudflare Tunnel]
    ↓
[Rack::Attack]  ← Layer 2: Application layer protection
    ↓
[Rails Application]
```

### Responsibility Division

| Layer | Responsibility | Advantages | Disadvantages |
|------|------|------|------|
| **Cloudflare** | Block obvious attacks (DDoS, known bad IPs, bots) | ✅ Doesn't consume app server resources<br>✅ Global CDN network<br>✅ Real-time threat intelligence | ❌ Cannot identify business logic<br>❌ Cannot distinguish user identity |
| **Rack::Attack** | Business logic-related limits (per user, per endpoint) | ✅ Fine-grained control<br>✅ Understands application logic<br>✅ Can adjust based on user tier | ❌ Consumes app server resources<br>❌ Requires configuration maintenance |

### Cloudflare Rate Limiting Configuration

**Cloudflare Dashboard → Security → WAF → Rate limiting rules**

```yaml
# Rule 1: Global DDoS Protection
Name: Global DDoS Protection
Criteria: All requests
Action: Block
Rate: 1000 requests per 10 seconds per IP
Duration: 1 hour

# Rule 2: Login Endpoint Protection (works with Rack::Attack)
Name: Login Protection
Criteria: URI Path equals "/api/v1/login" AND Method equals "POST"
Action: Managed Challenge
Rate: 10 requests per 1 minute per IP
Duration: 10 minutes

# Rule 3: API Endpoint Protection
Name: API Protection
Criteria: URI Path starts with "/api/"
Action: Block
Rate: 500 requests per 5 minutes per IP
Duration: 30 minutes
```

### Pass Real IP to Rails

**Problem:** Through Cloudflare Tunnel, Rails sees Cloudflare's IP

**Solution:** Use `CF-Connecting-IP` header

```ruby
# config/initializers/cloudflare_real_ip.rb
Rails.application.config.middleware.insert_before(
  Rack::Attack,
  Rack::Attack::StoreProxy::CfConnectingIp
)

# Or handle manually
class Rack::Attack
  class Request < ::Rack::Request
    def ip
      # Prioritize real IP provided by Cloudflare
      @ip ||= env['HTTP_CF_CONNECTING_IP'] || super
    end
  end
end
```

### Verify Cloudflare Tunnel Source

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Only accept requests from Cloudflare (if using Tunnel)
  blocklist('block-non-cloudflare') do |req|
    # Cloudflare IP ranges
    cloudflare_ips = [
      IPAddr.new('173.245.48.0/20'),
      IPAddr.new('103.21.244.0/22'),
      IPAddr.new('103.22.200.0/22'),
      # ... Complete list at https://www.cloudflare.com/ips/
    ]

    # If not from Cloudflare, block
    !cloudflare_ips.any? { |range| range.include?(req.ip) }
  end
end
```

### Cloudflare + Rack::Attack Collaboration Example

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Cloudflare already handles global DDoS
  # We focus on business logic-related limits

  # === Authenticated users (based on tier) ===

  throttle('api/user/pro', limit: 1000, period: 1.hour) do |req|
    user_id = authenticated_user_id(req)
    user_id if user_id && user_tier(user_id) == 'pro'
  end

  # === Expensive operations (Cloudflare doesn't know which endpoints are expensive) ===

  throttle('reports/user', limit: 1, period: 5.minutes) do |req|
    if req.path =~ /\/api\/.*\/reports$/ && req.post?
      user_id = authenticated_user_id(req)
      user_id if user_id
    end
  end

  # === What Cloudflare can't handle: Distributed attack on same account ===

  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/login' && req.post?
      email = req.params['email'].to_s.downcase.strip
      email.presence
    end
  end
end
```

---

## Testing Methods

### 1. RSpec Unit Tests

```ruby
# spec/requests/rate_limiting_spec.rb
require 'rails_helper'

RSpec.describe 'Rate Limiting', type: :request do
  let(:user) { create(:user, subscription_tier: 'free') }
  let(:headers) { { 'Authorization' => "Bearer #{generate_token(user)}" } }

  before do
    # Clear Redis (avoid test interference)
    Rails.cache.clear
  end

  describe 'API rate limiting' do
    it 'allows requests within limit' do
      50.times do
        get '/api/v1/products', headers: headers
        expect(response).to have_http_status(:ok)
      end
    end

    it 'blocks requests exceeding limit' do
      # Free tier: 100 requests/hour
      100.times { get '/api/v1/products', headers: headers }

      # 101st request should be blocked
      get '/api/v1/products', headers: headers
      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include('API quota exceeded')
    end

    it 'includes rate limit headers' do
      get '/api/v1/products', headers: headers

      expect(response.headers['X-RateLimit-Tier']).to eq('free')
      expect(response.headers['X-RateLimit-Hourly-Limit']).to eq('100')
      expect(response.headers['X-RateLimit-Hourly-Remaining']).to eq('99')
    end
  end

  describe 'Login rate limiting' do
    it 'blocks after 5 failed attempts from same IP' do
      5.times do
        post '/api/v1/login', params: { email: 'test@example.com', password: 'wrong' }
        expect(response).to have_http_status(:unauthorized)
      end

      # 6th attempt should be rate limited
      post '/api/v1/login', params: { email: 'test@example.com', password: 'wrong' }
      expect(response).to have_http_status(:too_many_requests)
    end

    it 'blocks after 5 attempts to same email from different IPs' do
      5.times do |i|
        # Simulate different IPs
        post '/api/v1/login',
             params: { email: 'victim@example.com', password: 'wrong' },
             headers: { 'REMOTE_ADDR' => "1.2.3.#{i}" }
      end

      # 6th attempt (even from different IP) should be blocked
      post '/api/v1/login',
           params: { email: 'victim@example.com', password: 'wrong' },
           headers: { 'REMOTE_ADDR' => '1.2.3.99' }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include('Too many login attempts for this account')
    end
  end

  describe 'Tier-based limits' do
    context 'Free tier' do
      it 'has 100 requests/hour limit' do
        100.times { get '/api/v1/products', headers: headers }

        get '/api/v1/products', headers: headers
        expect(response).to have_http_status(:too_many_requests)
      end
    end

    context 'Pro tier' do
      let(:pro_user) { create(:user, subscription_tier: 'pro') }
      let(:pro_headers) { { 'Authorization' => "Bearer #{generate_token(pro_user)}" } }

      it 'has 1000 requests/hour limit' do
        500.times { get '/api/v1/products', headers: pro_headers }

        get '/api/v1/products', headers: pro_headers
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
```

### 2. Load Testing (using Apache Bench)

```bash
# Test basic endpoint
ab -n 1000 -c 10 http://localhost:3000/api/v1/products

# Test login endpoint (should be rate limited quickly)
ab -n 100 -c 5 -p login.json -T application/json \
   http://localhost:3000/api/v1/login

# login.json:
# {"email":"test@example.com","password":"wrong"}
```

### 3. Manual Testing with curl

```bash
# Test rate limit
for i in {1..10}; do
  echo "Request $i:"
  curl -s -w "\nHTTP Status: %{http_code}\n" \
    -H "Authorization: Bearer <token>" \
    http://localhost:3000/api/v1/products
  echo "---"
done

# Test 429 response
curl -v -H "Authorization: Bearer <token>" \
  http://localhost:3000/api/v1/products

# View headers
curl -I -H "Authorization: Bearer <token>" \
  http://localhost:3000/api/v1/products

# Output:
# X-RateLimit-Tier: free
# X-RateLimit-Hourly-Limit: 100
# X-RateLimit-Hourly-Remaining: 92
```

### 4. Monitor Redis Keys

```bash
# View all Rack::Attack keys
docker exec redis_cache redis-cli KEYS "rack::attack:*"

# View specific key value
docker exec redis_cache redis-cli GET "rack::attack:api/user:123"

# View TTL
docker exec redis_cache redis-cli TTL "rack::attack:api/user:123"

# Manual reset (for testing)
docker exec redis_cache redis-cli DEL "rack::attack:api/user:123"
```

---

## Monitoring and Alerting

### Prometheus Metrics

```ruby
# config/initializers/prometheus.rb
require 'prometheus_exporter/instrumentation'

# Rack::Attack metrics
module Rack
  class Attack
    class << self
      alias_method :original_track, :track

      def track(name, options = {}, &block)
        result = original_track(name, options, &block)

        # Record metrics
        PrometheusExporter::Client.default.send_json(
          type: 'rack_attack',
          name: name,
          action: result ? 'throttled' : 'allowed'
        )

        result
      end
    end
  end
end

# Prometheus Exporter
class RackAttackCollector < PrometheusExporter::Server::TypeCollector
  def type
    'rack_attack'
  end

  def metrics
    requests = @observer.calls.group_by { |c| [c[:name], c[:action]] }
                      .transform_values(&:count)

    gauge = PrometheusExporter::Metric::Gauge.new(
      'rack_attack_requests_total',
      'Total number of requests processed by Rack::Attack'
    )

    requests.each do |(name, action), count|
      gauge.observe(count, name: name, action: action)
    end

    [gauge]
  end
end

# Register collector
PrometheusExporter::Server::Runner.start(
  collectors: [RackAttackCollector.new]
)
```

### Grafana Dashboard

```yaml
# Grafana Dashboard JSON (simplified)
panels:
  - title: Rate Limit Hit Rate
    targets:
      - expr: rate(rack_attack_requests_total{action="throttled"}[5m])

  - title: Top Throttled IPs
    targets:
      - expr: topk(10, sum by(ip) (rack_attack_requests_total{action="throttled"}))

  - title: Throttled vs Allowed
    targets:
      - expr: sum by(action) (rack_attack_requests_total)
```

### Alert Rules

```yaml
# Prometheus alerts
groups:
  - name: rack_attack
    rules:
      # High proportion of throttled requests (possible attack)
      - alert: HighThrottleRate
        expr: |
          rate(rack_attack_requests_total{action="throttled"}[5m])
          /
          rate(rack_attack_requests_total[5m])
          > 0.1
        for: 5m
        annotations:
          summary: "High rate of throttled requests"
          description: "{{ $value | humanizePercentage }} of requests are being throttled"

      # Specific endpoint under heavy requests
      - alert: EndpointUnderAttack
        expr: |
          rate(rack_attack_requests_total{name=~"logins/.*", action="throttled"}[1m])
          > 10
        for: 2m
        annotations:
          summary: "Login endpoint under attack"
          description: "{{ $value }} throttled login attempts per second"
```

### Logging

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Log throttled requests
  ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
    req = payload[:request]

    if req.env['rack.attack.matched']
      Rails.logger.warn({
        message: 'Request throttled by Rack::Attack',
        rule: req.env['rack.attack.matched'],
        discriminator: req.env['rack.attack.match_discriminator'],
        ip: req.ip,
        path: req.path,
        user_agent: req.user_agent
      }.to_json)
    end
  end

  # Log blocked requests
  Rack::Attack.blocklisted_responder = lambda do |env|
    req = Rack::Request.new(env)

    Rails.logger.error({
      message: 'Request blocked by Rack::Attack',
      rule: req.env['rack.attack.matched'],
      ip: req.ip,
      path: req.path,
      user_agent: req.user_agent
    }.to_json)

    [403, { 'Content-Type' => 'text/plain' }, ['Forbidden']]
  end
end
```

---

## Troubleshooting

### Problem 1: Normal Users Getting Blocked

**Symptoms:**
```
User reports: "I didn't do anything, but got 429 Too Many Requests"
```

**Possible Causes:**

1. **NAT/Company Network Shared IP**
   ```
   Company office:
   ├─ 50 employees
   └─ Share same public IP

   Rate limit: 100 req/hour per IP
   Each employee can only do 2 req/hour → Too strict!
   ```

**Solution:**
```ruby
# Use user-based throttling for authenticated users
throttle('api/user', limit: 1000, period: 1.hour) do |req|
  user_id = authenticated_user_id(req)
  user_id if user_id
end

# IP-based only for unauthenticated users, and more lenient
throttle('api/ip', limit: 300, period: 5.minutes) do |req|
  req.ip unless authenticated_user_id(req)
end
```

2. **Limits Too Strict**

**Solution:** Adjust limit values
```ruby
# ❌ Too strict
throttle('api/ip', limit: 10, period: 1.minute)

# ✅ Reasonable
throttle('api/ip', limit: 100, period: 1.minute)
```

3. **Not Considering SPA API Call Patterns**

```javascript
// React SPA initial load
useEffect(() => {
  // Send 10 API requests simultaneously
  Promise.all([
    fetchUser(),
    fetchProducts(),
    fetchCategories(),
    fetchCart(),
    // ...
  ])
}, [])

// May instantly exceed limit!
```

**Solution:**
```ruby
# Use longer period (allow short-term bursts)
throttle('api/ip', limit: 300, period: 5.minutes) do |req|
  req.ip
end

# Or implement Token Bucket (allows bursts)
```

---

### Problem 2: Redis Memory Usage Too High

**Symptoms:**
```bash
docker exec redis_cache redis-cli INFO memory
# used_memory: 800MB (approaching maxmemory 1GB)
```

**Cause:** Too many Rack::Attack keys

```bash
# Check key count
docker exec redis_cache redis-cli DBSIZE
# keys: 500,000

docker exec redis_cache redis-cli KEYS "rack::attack:*" | wc -l
# 450,000 keys (90%!)
```

**Solutions:**

1. **Reduce discriminator granularity**
```ruby
# ❌ Too granular (each session counts independently)
throttle('api/session', limit: 100, period: 1.hour) do |req|
  req.session[:id]  # May have hundreds of thousands of different sessions
end

# ✅ Use user ID (fewer count)
throttle('api/user', limit: 100, period: 1.hour) do |req|
  authenticated_user_id(req)
end
```

2. **Clean up expired keys**
```ruby
# Rack::Attack automatically sets TTL
# But can manually clean long-inactive keys

# lib/tasks/rack_attack.rake
namespace :rack_attack do
  desc 'Clean up old Rack::Attack keys'
  task cleanup: :environment do
    pattern = 'rack::attack:*'
    cursor = '0'

    loop do
      cursor, keys = REDIS_CACHE.with { |r| r.scan(cursor, match: pattern, count: 1000) }

      keys.each do |key|
        # If no TTL, set one
        ttl = REDIS_CACHE.with { |r| r.ttl(key) }
        if ttl == -1
          REDIS_CACHE.with { |r| r.expire(key, 3600) }
        end
      end

      break if cursor == '0'
    end
  end
end

# Cron job: Execute daily
```

---

### Problem 3: Attackers Bypassing Rate Limiting

**Symptoms:**
```
Attack continues, but Rack::Attack shows limits are active
```

**Possible Causes:**

1. **Using Multiple IPs (Distributed Attack)**
```
Attacker uses botnet:
├─ IP 1: 50 req/min (doesn't exceed limit)
├─ IP 2: 50 req/min
├─ IP 3: 50 req/min
...
└─ IP 100: 50 req/min

Total: 5000 req/min → Server crashes
```

**Solution:**
```ruby
# Add global limit (regardless of source)
throttle('global', limit: 1000, period: 1.minute) do |req|
  'global'  # All requests share same counter
end

# Add Cloudflare WAF (block at edge)
```

2. **Header Spoofing**
```ruby
# Attacker spoofs X-Forwarded-For header
# ❌ Wrong approach
def client_ip
  request.headers['X-Forwarded-For']  # Can be spoofed!
end

# ✅ Correct approach
def client_ip
  request.remote_ip  # Rails correctly handles trusted proxies
end
```

**Configure trusted proxies:**
```ruby
# config/application.rb
config.action_dispatch.trusted_proxies = [
  IPAddr.new('10.0.0.0/8'),      # Internal network
  IPAddr.new('172.16.0.0/12'),   # Docker network
  IPAddr.new('192.168.0.0/16')   # Private network
]
```

3. **Using Different User-Agents**
```ruby
# Simple bots may be blocked
# But advanced bots mimic real browsers

# Solution: Combine multiple indicators
throttle('suspicious', limit: 50, period: 1.minute) do |req|
  # Check multiple indicators
  if suspicious_behavior?(req)
    req.ip
  end
end

def suspicious_behavior?(req)
  # 1. No Referer header
  no_referer = req.referer.nil?

  # 2. User-Agent is known bot
  known_bot = req.user_agent =~ /bot|crawler|spider/i

  # 3. Request speed abnormally fast (< 100ms interval)
  last_request_time = REDIS_CACHE.with { |r| r.get("last:#{req.ip}") }
  too_fast = last_request_time && (Time.now.to_f - last_request_time.to_f) < 0.1

  no_referer || known_bot || too_fast
end
```

---

### Problem 4: Redis Connection Error

**Symptoms:**
```
Redis::CannotConnectError: Error connecting to Redis on redis_cache:6379
```

**Cause:** Redis not started or network issues

**Solutions:**

1. **Check Redis status**
```bash
docker ps | grep redis_cache
docker logs redis_cache
```

2. **Set Fallback (graceful degradation)**
```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Set error handler
  self.cache.error_handler = lambda do |method:, returning:, exception:|
    Rails.logger.error({
      message: 'Rack::Attack cache error',
      method: method,
      exception: exception.class.name,
      error: exception.message
    }.to_json)

    # Return default value (allow request to pass)
    returning
  end

  # Or use memory store as fallback
  if Rails.cache.is_a?(ActiveSupport::Cache::RedisCacheStore)
    begin
      Rails.cache.ping
    rescue
      Rails.logger.warn 'Redis unavailable, using memory store for Rack::Attack'
      self.cache = ActiveSupport::Cache::MemoryStore.new
    end
  end
end
```

---

## Security Considerations

### 1. IP Spoofing Protection

**Problem:** Attacker spoofs `X-Forwarded-For` header

```http
GET /api/v1/products HTTP/1.1
X-Forwarded-For: 127.0.0.1
```

**Protection:**

```ruby
# config/application.rb
# Only trust specific proxies
config.action_dispatch.trusted_proxies = [
  '10.0.0.0/8',      # Internal network
  '172.16.0.0/12',   # Docker
  '192.168.0.0/16'   # Private
]

# Rack::Attack uses request.remote_ip (automatically handles trusted proxies)
```

### 2. Timing Attack Protection

**Problem:** Attacker judges limit status through response time

```ruby
# ❌ Has timing difference
if rate_limited?(req)
  expensive_check()  # Needs 100ms
  return 429
else
  return 200
end

# Attacker can judge if close to limit through response time
```

**Protection:**

```ruby
# ✅ Ensure consistent response time
throttle('api/ip', limit: 100, period: 1.minute) do |req|
  req.ip
end

# Rack::Attack check is very fast (< 1ms)
# Doesn't leak timing information
```

### 3. Bypass Specific Paths

```ruby
# Ensure critical paths aren't bypassed
class Rack::Attack
  # ❌ Dangerous: Admin interface completely bypassed
  safelist('allow-admin') do |req|
    req.path.start_with?('/admin')
  end

  # ✅ Safe: Only bypass healthcheck
  safelist('allow-healthcheck') do |req|
    req.path == '/up' && req.get?
  end

  # Admin interface should have independent limits (stricter)
  throttle('admin/ip', limit: 10, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/admin')
  end
end
```

### 4. DDoS Amplification Protection

**Problem:** Expensive endpoints being abused

```ruby
# ❌ Expensive endpoint without limits
GET /api/reports?year=2024&include=all_details

# This query needs 30 seconds + lots of memory
# Attacker sends 100 such requests → server paralyzed
```

**Protection:**

```ruby
# ✅ Very strict limits for expensive endpoints
throttle('reports/user', limit: 1, period: 10.minutes) do |req|
  if req.path =~ /\/reports$/ && req.get?
    authenticated_user_id(req)
  end
end

# Or convert to background job
def create
  job = ReportGenerationJob.perform_later(params)
  render json: { job_id: job.job_id }, status: :accepted
end
```

---

## Performance Optimization

### 1. Redis Connection Pooling

**This template is already configured!**

```ruby
# gem/redis.rb already configured
pool_size = ENV.fetch('RAILS_MAX_THREADS', 16).to_i

Rails.application.config.cache_store = :redis_cache_store, {
  pool_size: pool_size,  # ← Connection pool
  pool_timeout: 5
}
```

### 2. Bypass Specific Paths (reduce checks)

```ruby
class Rack::Attack
  # Healthcheck endpoint doesn't need limits
  safelist('allow-healthcheck') do |req|
    req.path == '/up' && req.get?
  end

  # ActiveStorage file access doesn't need limits (if using)
  safelist('allow-storage') do |req|
    req.path.start_with?('/rails/active_storage/')
  end
end
```

### 3. Use Longer Period (reduce Redis operations)

```ruby
# ❌ Too frequent Redis operations
throttle('api/ip', limit: 1, period: 1.second) do |req|
  req.ip
end
# Each request = INCR + EXPIRE → 2 Redis operations

# ✅ Fewer Redis operations
throttle('api/ip', limit: 60, period: 1.minute) do |req|
  req.ip
end
# Same rate limit (60 req/min), but fewer Redis operations
```

### 4. Monitor Rack::Attack Performance Impact

```ruby
# config/initializers/rack_attack.rb
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, id, payload|
  duration = (finish - start) * 1000  # ms

  Rails.logger.debug({
    message: 'Rack::Attack timing',
    duration_ms: duration,
    matched: payload[:request].env['rack.attack.matched']
  }.to_json)

  # If > 10ms, warn
  if duration > 10
    Rails.logger.warn "Rack::Attack slow: #{duration}ms"
  end
end
```

---

## Summary

### Key Points

1. **No one-size-fits-all configuration**
   - Choose strategy based on application type
   - Continuous monitoring and adjustment

2. **Multi-layer protection**
   - IP-based (basic protection)
   - User-based (precise control)
   - Endpoint-based (protect expensive operations)

3. **Cloudflare + Rack::Attack**
   - Cloudflare: Edge protection (DDoS, bot)
   - Rack::Attack: Business logic-related limits

4. **Monitoring is key**
   - Prometheus metrics
   - Alert rules
   - Logging

5. **Graceful degradation**
   - Fallback when Redis fails
   - Provide clear error messages
   - Display remaining quota

### Quick Start Checklist

```markdown
□ Installation
  □ Rack::Attack gem installed
  □ Redis as cache store

□ Configuration
  □ Choose strategy based on application type
  □ Set appropriate limit values
  □ Configure custom response

□ Testing
  □ Unit tests pass
  □ Load testing verified
  □ Monitor Redis keys

□ Monitoring
  □ Prometheus metrics
  □ Alert rules set
  □ Log recording

□ Security
  □ Trusted proxies configured
  □ IP spoofing protection
  □ Minimize bypass paths

□ Documentation
  □ API docs explain rate limit
  □ Team understands configuration
  □ Monitoring dashboard created
```

### Related Documents

- [REDIS_ARCHITECTURE.md](./REDIS_ARCHITECTURE.md) - Redis configuration and best practices
- [CLOUDFLARE_TUNNEL.md](./CLOUDFLARE_TUNNEL.md) - Cloudflare integration
- [AUTHENTICATION.md](./AUTHENTICATION.MD) - Authentication and authorization
- [MEMORY_OPTIMIZATION.md](./MEMORY_OPTIMIZATION.md) - Memory optimization
