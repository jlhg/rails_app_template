# Authentication Architecture Guide

This document explains the recommended authentication architecture for this Rails API template, focusing on access token management with Redis and PostgreSQL.

## Table of Contents

- [Overview](#overview)
- [Architecture Decision](#architecture-decision)
- [Why Redis + PostgreSQL?](#why-redis--postgresql)
- [Token Storage Strategy](#token-storage-strategy)
- [Implementation Concepts](#implementation-concepts)
- [Security Best Practices](#security-best-practices)
- [Performance Considerations](#performance-considerations)
- [Alternatives Comparison](#alternatives-comparison)

## Overview

For API-only Rails applications, you need a strategy to authenticate users across stateless HTTP requests. This guide recommends a **hybrid approach** using both Redis and PostgreSQL.

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Request                            │
│            Authorization: Bearer <token>                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  Token Verification    │
            │  1. Check Redis cache  │◄────── Fast path (< 1ms)
            │  2. Check PostgreSQL   │◄────── Fallback (5-20ms)
            │  3. Return user        │
            └────────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  Authorized Request    │
            │  Processing            │
            └────────────────────────┘
```

## Architecture Decision

### Recommended: Redis (Cache) + PostgreSQL (Source of Truth)

**Storage**:
- PostgreSQL: Stores token digest, metadata, audit information
- Redis (redis_session): Caches token → user_id mapping for fast lookup

**Workflow**:
1. **Login**: Create token, save to PostgreSQL, cache in Redis
2. **Request**: Check Redis first (fast), fallback to PostgreSQL
3. **Logout**: Delete from both Redis and PostgreSQL

**Benefits**:
- ⚡ Fast: 95%+ requests served from Redis (< 1ms)
- 🔒 Reliable: PostgreSQL ensures no data loss
- 🚀 Scalable: Redis handles high request rates
- 📊 Auditable: PostgreSQL tracks token history
- 🛡️ Recoverable: Works even if Redis fails

## Why Redis + PostgreSQL?

### The Problem with JWT Only

**JWT (JSON Web Tokens)**:
```ruby
token = JWT.encode({ user_id: user.id, exp: 24.hours.from_now }, secret)
```

**Pros**:
- Stateless (no storage needed)
- Fast verification
- Can include claims (roles, permissions)

**Fatal Flaws**:
- ❌ **Cannot revoke** (until expiration)
- ❌ **Cannot track active sessions**
- ❌ **Security risk**: Stolen token works until expiry

**Example scenario**:
```
1. User reports: "My account was hacked!"
2. You: "I'll immediately revoke all sessions"
3. Reality: ❌ Cannot revoke JWT tokens
4. Hacker: Still has valid JWT for next 24 hours
```

### The Problem with Redis Only

**Redis-only tokens**:
```ruby
token = SecureRandom.hex(32)
REDIS_SESSION.with { |r| r.setex("token:#{token}", 24.hours, user.id) }
```

**Pros**:
- Fast lookup
- Easy to revoke
- Simple implementation

**Fatal Flaws**:
- ❌ **Data loss risk**: Redis restart = all users logged out
- ❌ **No audit trail**: Cannot track token history
- ❌ **No recovery**: Lost data is gone forever

**Example scenario**:
```
1. Redis crashes/restarts
2. All 10,000 active users: ❌ Logged out immediately
3. Support tickets: 📈📈📈
4. You: "Sorry, we lost all sessions"
```

### The Solution: Redis + PostgreSQL

**Hybrid approach**:
```ruby
# On login:
1. Generate opaque token
2. Save to PostgreSQL (with digest, metadata)
3. Cache in Redis (token → user_id)

# On request:
1. Check Redis (fast path)
2. If miss, check PostgreSQL (slow path + warm Redis)
3. Return user

# On logout:
1. Mark as revoked in PostgreSQL
2. Delete from Redis (immediate effect)
```

**Achieves**:
- ✅ Speed: Redis cache (< 1ms)
- ✅ Reliability: PostgreSQL persistence
- ✅ Revocation: Delete Redis key (immediate)
- ✅ Audit: PostgreSQL tracks everything
- ✅ Recovery: Redis crash = minor slowdown (not disaster)

## Token Storage Strategy

### PostgreSQL Schema

**Recommended structure**:
```ruby
# app/models/access_token.rb
class AccessToken < ApplicationRecord
  belongs_to :user

  # Columns:
  # - token_digest:string (indexed, unique) - SHA256 of token
  # - user_id:integer (indexed) - Owner
  # - expires_at:datetime (indexed) - Expiration
  # - revoked_at:datetime (indexed) - Revocation timestamp
  # - last_used_at:datetime - Last access time
  # - ip_address:string - Created from IP
  # - user_agent:string - Browser/app info
  # - created_at:datetime
  # - updated_at:datetime
end
```

**Why store digest, not plaintext?**
```ruby
# ❌ Never store plaintext
token = "abc123"
AccessToken.create!(token: token)  # Database breach = all tokens stolen

# ✅ Store digest
token = SecureRandom.urlsafe_base64(32)
digest = Digest::SHA256.hexdigest(token)
AccessToken.create!(token_digest: digest)  # Database breach = tokens safe

# Token only exposed once (on login response)
# Cannot be recovered from database
```

### Redis Storage

**Structure**:
```ruby
# Simple key-value mapping
key: "token:#{raw_token}"
value: user_id (or JSON with more data)
TTL: same as token expiry
```

**Example**:
```ruby
REDIS_SESSION.with do |redis|
  redis.setex(
    "token:abc123xyz",
    24.hours.to_i,
    user.id.to_s
  )
end
```

**Why redis_session, not redis_cache?**
- redis_session: `noeviction` + AOF persistence
- redis_cache: `allkeys-lru` (tokens could be evicted!)

See [REDIS_ARCHITECTURE.md](./REDIS_ARCHITECTURE.md) for details.

## Implementation Concepts

### Token Generation

**Conceptual flow**:
```ruby
def create_token_for(user)
  # 1. Generate cryptographically secure token
  token = SecureRandom.urlsafe_base64(32)  # 256-bit entropy

  # 2. Create database record
  record = AccessToken.create!(
    user: user,
    token_digest: Digest::SHA256.hexdigest(token),
    expires_at: 24.hours.from_now,
    ip_address: request.remote_ip,
    user_agent: request.user_agent
  )

  # 3. Cache in Redis
  REDIS_SESSION.with do |redis|
    redis.setex(
      "token:#{token}",
      24.hours.to_i,
      user.id
    )
  end

  # 4. Return token (only time it's visible)
  token
end
```

### Token Verification

**Conceptual flow**:
```ruby
def authenticate_token(token)
  # 1. Fast path: Check Redis cache
  user_id = REDIS_SESSION.with { |r| r.get("token:#{token}") }

  if user_id
    return User.find(user_id)
  end

  # 2. Slow path: Check PostgreSQL
  digest = Digest::SHA256.hexdigest(token)
  record = AccessToken.active.find_by(token_digest: digest)

  if record
    # 3. Warm Redis cache
    REDIS_SESSION.with do |redis|
      ttl = (record.expires_at - Time.current).to_i
      redis.setex("token:#{token}", ttl, record.user_id)
    end

    # 4. Update last_used_at (async recommended)
    record.update_column(:last_used_at, Time.current)

    return record.user
  end

  nil  # Invalid token
end
```

**Cache hit rate**: Typically 95-99% (Redis serves most requests)

### Token Revocation

**Conceptual flow**:
```ruby
def revoke_token(token)
  digest = Digest::SHA256.hexdigest(token)

  # 1. Mark as revoked in PostgreSQL
  record = AccessToken.find_by(token_digest: digest)
  record&.update!(revoked_at: Time.current)

  # 2. Delete from Redis (immediate effect)
  REDIS_SESSION.with { |r| r.del("token:#{token}") }
end
```

**Why both?**
- PostgreSQL: Audit trail (who revoked, when)
- Redis: Immediate effect (next request sees revocation)

## Security Best Practices

### 1. Token Entropy

```ruby
# ✅ Good: 256-bit entropy
SecureRandom.urlsafe_base64(32)  # 43 chars, URL-safe

# ❌ Bad: Low entropy
SecureRandom.hex(8)  # Only 64-bit (bruteforceable)
```

### 2. Short Expiration

```ruby
# ✅ Access tokens: Short-lived
expires_at: 1.day.from_now  # or even 1.hour

# ✅ Refresh tokens: Longer-lived (separate implementation)
refresh_token_expires_at: 30.days.from_now
```

**Refresh token pattern**:
- Access token: 1 hour (for API requests)
- Refresh token: 30 days (to get new access token)
- Stolen access token: Limited damage (1 hour)

### 3. Never Store Plaintext

```ruby
# ❌ NEVER
AccessToken.create!(token: raw_token)

# ✅ ALWAYS
AccessToken.create!(token_digest: Digest::SHA256.hexdigest(raw_token))
```

### 4. Secure Transmission

```ruby
# ✅ HTTPS only in production
config.force_ssl = true

# ✅ Authorization header (not URL/body)
Authorization: Bearer <token>

# ❌ Never in URL
GET /api/users?token=abc123  # Logged in server logs!
```

### 5. Rate Limiting

```ruby
# Use Rack::Attack to prevent brute force
Rack::Attack.throttle('logins/email', limit: 5, period: 1.minute) do |req|
  req.params['email'] if req.path == '/api/login' && req.post?
end
```

### 6. IP and User-Agent Tracking

```ruby
# Detect suspicious activity
if token.ip_address != request.remote_ip
  # Log suspicious activity
  # Maybe require re-authentication
  # Or send alert to user
end
```

### 7. Token Rotation

```ruby
# After password change, revoke all tokens
user.access_tokens.active.each(&:revoke!)

# After suspicious activity
user.access_tokens.where('created_at < ?', 1.hour.ago).each(&:revoke!)
```

## Performance Considerations

### Redis Cache Hit Rate

**Target**: > 95% cache hit rate

**Calculation**:
```ruby
# Monitor in production
total_requests = 10000
redis_hits = 9500
cache_hit_rate = (redis_hits / total_requests.to_f) * 100
# => 95%
```

**If hit rate is low**:
- Increase Redis memory
- Increase token TTL in Redis
- Check Redis eviction policy (should be `noeviction`)

### Database Connection Pool

```ruby
# config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 16) %>
```

**Important**: Even with Redis cache, PostgreSQL pool must handle:
- Cache misses (5%)
- Token creation (logins)
- Token revocation (logouts)

### Async Updates

```ruby
# ❌ Slow: Update last_used_at synchronously
token.update!(last_used_at: Time.current)  # Blocks request

# ✅ Fast: Update asynchronously
UpdateTokenLastUsedJob.perform_later(token.id)
```

### Token Cleanup

```ruby
# Delete expired tokens (run daily via cron)
AccessToken.where('expires_at < ?', 30.days.ago).delete_all
```

**Why 30 days ago, not today?**
- Keep expired tokens for audit
- Delete only old expired tokens

## Alternatives Comparison

### Option 1: JWT with Blacklist

**Concept**:
- Use JWT for most requests (stateless)
- Blacklist revoked JWTs in Redis

```ruby
# Verify JWT
def valid_token?(jwt)
  decoded = JWT.decode(jwt, secret)[0]
  jti = decoded['jti']  # JWT ID

  # Check blacklist
  !REDIS_SESSION.with { |r| r.exists?("blacklist:#{jti}") }
end

# Revoke JWT
def revoke_jwt(jwt)
  decoded = JWT.decode(jwt, secret)[0]
  jti = decoded['jti']
  exp = decoded['exp']

  # Add to blacklist (only until expiry)
  ttl = exp - Time.current.to_i
  REDIS_SESSION.with { |r| r.setex("blacklist:#{jti}", ttl, 1) }
end
```

**Pros**:
- 99% requests don't need storage (just verify signature)
- Scalable (stateless)

**Cons**:
- Still need Redis (blacklist)
- Still need PostgreSQL (audit, if wanted)
- More complex than opaque tokens
- Blacklist can grow large

**When to use**: High-scale APIs (> 100k RPS) where DB is bottleneck

### Option 2: PostgreSQL Only

**Concept**:
- Store all tokens in PostgreSQL
- No Redis cache

**Pros**:
- Simple architecture
- Reliable (no Redis dependency)
- Complete audit trail

**Cons**:
- Slow (5-20ms per request)
- High database load (every API request queries DB)
- Limited scalability

**When to use**: Low-traffic internal APIs, or when simplicity > performance

### Option 3: Rails Sessions (Cookies)

**Concept**:
- Use Rails' built-in session management
- Store session ID in cookie

**Pros**:
- Built into Rails
- Simple to implement

**Cons**:
- ❌ **Not suitable for APIs** (cookies don't work well with mobile apps, SPAs)
- ❌ CSRF protection needed
- ❌ Cookie size limits

**When to use**: Traditional Rails apps with server-rendered views (not APIs)

## Summary

**Recommended**: Redis (redis_session) + PostgreSQL

**Why**:
- ✅ Fast (< 1ms typical response)
- ✅ Reliable (PostgreSQL persistence)
- ✅ Secure (immediate revocation)
- ✅ Auditable (complete history)
- ✅ Scalable (Redis handles load)

**Not recommended**: JWT-only (cannot revoke)

**Implementation**: Left to developer based on specific requirements

**Key Principle**: Use `redis_session` instance (not `redis_cache`) to prevent token eviction

See also: [Redis Architecture Guide](./REDIS_ARCHITECTURE.md)
