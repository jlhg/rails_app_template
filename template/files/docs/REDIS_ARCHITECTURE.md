# Valkey/Redis Architecture Guide

This Rails template uses **Valkey by default** (a fully open-source, Redis-compatible alternative) with **three separate instances** for different purposes. Each instance has different eviction policies, persistence settings, and memory limits. This document explains the rationale behind this architecture and when you might need to adjust it.

## Table of Contents

- [Valkey vs Redis](#valkey-vs-redis)
- [Switching to Redis](#switching-to-redis)
- [Overview](#overview)
- [Redis Instances](#redis-instances)
- [Why Multiple Redis?](#why-multiple-redis)
- [Configuration Details](#configuration-details)
- [Memory Allocation](#memory-allocation)
- [Eviction Policies](#eviction-policies)
- [Persistence Strategies](#persistence-strategies)
- [Use Cases](#use-cases)
- [Monitoring](#monitoring)
- [Scaling Guide](#scaling-guide)
- [Alternative Architectures](#alternative-architectures)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

## Valkey vs Redis

### Why Valkey?

This template uses **Valkey** as the default in-memory data store instead of Redis for the following reasons:

#### 1. Fully Open Source (BSD-3 License)
- **Valkey**: 100% open source under BSD-3-Clause license (no restrictions)
- **Redis**: Dual-licensed with RSALv2/SSPLv1 since Redis 7.4 (2024-03)
  - Restrictive licensing for cloud providers and commercial use
  - Cannot be packaged by some Linux distributions

#### 2. Linux Foundation Backing
- Maintained by Linux Foundation with support from:
  - AWS (Amazon ElastiCache team)
  - Google Cloud
  - Oracle
  - Alibaba Cloud
- Long-term sustainability and community governance

#### 3. 100% Protocol Compatibility
- **Drop-in replacement** for Redis 7.2 and earlier
- All Redis commands work identically
- Same wire protocol (RESP)
- Existing Redis clients (redis-rb) work without changes
- No code changes needed in your Rails application

#### 4. Better Performance
- **Valkey 8.0**: 3x higher throughput compared to Redis 7.2
- Improved memory efficiency
- Better multi-threading support
- Active development focused on performance

#### 5. Production Ready (2025)
- Used by major cloud providers (AWS ElastiCache for Valkey)
- Battle-tested by large-scale deployments
- Active community and rapid bug fixes
- Regular security updates

### Compatibility Matrix

| Feature | Valkey 8.x | Valkey 7.x | Redis 7.2 | Redis 7.4+ |
|---------|-----------|-----------|-----------|------------|
| RESP Protocol | ✅ | ✅ | ✅ | ✅ |
| All Redis Commands | ✅ | ✅ | ✅ | ✅ |
| Pub/Sub | ✅ | ✅ | ✅ | ✅ |
| Clustering | ✅ | ✅ | ✅ | ✅ |
| Sentinel | ✅ | ✅ | ✅ | ✅ |
| Modules API | ✅ | ✅ | ✅ | ⚠️ (licensing) |
| redis-rb gem | ✅ | ✅ | ✅ | ✅ |
| License | BSD-3 | BSD-3 | BSD-3 | RSALv2/SSPLv1 |
| Performance | 🚀 3x faster | ✅ | ✅ | ✅ |

### Migration from Redis

If you're migrating an existing Redis deployment to Valkey:

1. **Zero code changes required** - Valkey is 100% compatible
2. **Data migration**: Export from Redis, import to Valkey (same RDB/AOF format)
3. **Client compatibility**: All Redis clients work with Valkey
4. **Performance**: Expect same or better performance

### Performance Comparison (2025)

| Metric | Valkey 8.0 | Valkey 7.2 | Redis 7.2 | Notes |
|--------|------------|------------|-----------|-------|
| Throughput | **100%** | 60% | 33% | 3x improvement over Redis |
| Memory Efficiency | **100%** | 95% | 105% | Best-in-class memory usage |
| Latency (p99) | **100%** | 105% | 110% | Lowest latency |
| Multi-threading | ✅ Enhanced | ✅ Good | ⚠️ Limited | Better CPU utilization |

Source: [Valkey 8.0 announcement](https://valkey.io/blog/)

**Why Valkey 8.0**: This template uses Valkey 8.0 for the best performance and latest features.

## Switching to Redis

If you prefer to use Redis instead of Valkey, you only need to change the Docker image:

### Option 1: Edit compose.yaml

```yaml
# Change all three instances in compose.yaml:

# Before (Valkey 8)
redis_cache:
  image: valkey/valkey:8-alpine

redis_cable:
  image: valkey/valkey:8-alpine

redis_session:
  image: valkey/valkey:8-alpine

# After (Redis 7)
redis_cache:
  image: redis:7-alpine

redis_cable:
  image: redis:7-alpine

redis_session:
  image: redis:7-alpine
```

### Option 2: Use compose override file

Create `compose.override.yaml` (automatically loaded by Docker Compose):

```yaml
# compose.override.yaml
services:
  redis_cache:
    image: redis:7-alpine

  redis_cable:
    image: redis:7-alpine

  redis_session:
    image: redis:7-alpine
```

This way you can keep the original `compose.yaml` unchanged.

### No Other Changes Needed

- ✅ Rails configuration stays the same (gem/redis.rb)
- ✅ Environment variables stay the same
- ✅ Connection URLs stay the same
- ✅ All commands work identically
- ✅ No code changes in your application

The `redis-rb` gem works with both Valkey and Redis transparently.

### Redis Version Notes

If using Redis, be aware of licensing:

- **Redis 7.2 or earlier**: BSD-3 license (recommended if using Redis)
- **Redis 7.4 or later**: RSALv2/SSPLv1 license (restrictive for some use cases)

For most users, we recommend staying with Valkey unless you have specific Redis-only requirements.

## Overview

```
┌──────────────────────────────────────────────────────────────┐
│                      Rails Application                        │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │Rails.cache  │    │ ActionCable │    │   Access    │      │
│  │ Rack::Attack│    │  WebSocket  │    │   Tokens    │      │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘      │
│         │                  │                   │              │
└─────────┼──────────────────┼───────────────────┼──────────────┘
          │                  │                   │
          ▼                  ▼                   ▼
   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
   │redis_cache  │    │redis_cable  │    │redis_session│
   │  (Valkey)   │    │  (Valkey)   │    │  (Valkey)   │
   │ LRU evict   │    │ No eviction │    │ No eviction │
   │ No persist  │    │ No persist  │    │ AOF persist │
   │   1GB RAM   │    │  512MB RAM  │    │  512MB RAM  │
   └─────────────┘    └─────────────┘    └─────────────┘
```

## Valkey/Redis Instances

This template uses three separate Valkey instances (or Redis if you switch). Throughout this document, we refer to them as "Valkey/Redis" since they are 100% compatible.

### redis_cache

**Purpose**: Rails.cache, Rack::Attack rate limiting, temporary data

**Configuration**:
```yaml
redis_cache:
  maxmemory: 1gb
  maxmemory-policy: allkeys-lru
  persistence: none (--save "")
```

**Characteristics**:
- Data can be evicted when memory is full
- Data is ephemeral (no persistence)
- Data can be rebuilt from source
- High write/read frequency

**Use Cases**:
- `Rails.cache.fetch("key") { expensive_query }`
- API response caching
- Database query result caching
- Third-party API response caching
- Rate limiting counters (Rack::Attack)

### redis_cable

**Purpose**: ActionCable WebSocket pub/sub

**Configuration**:
```yaml
redis_cable:
  maxmemory: 512mb
  maxmemory-policy: noeviction
  persistence: none (--save "")
```

**Characteristics**:
- Cannot evict data (pub/sub must be delivered)
- Real-time data (no need to persist)
- Dedicated instance prevents FLUSHDB conflicts
- Lower memory needs (only active channels)

**Use Cases**:
- WebSocket connections
- Real-time notifications
- Live updates
- Chat messages (transient)

### redis_session

**Purpose**: Access tokens, user sessions, important state

**Configuration**:
```yaml
redis_session:
  maxmemory: 512mb
  maxmemory-policy: noeviction
  persistence: AOF (--appendonly yes --appendfsync everysec)
```

**Characteristics**:
- Cannot evict data (important user data)
- Persisted to disk (survives restarts)
- Critical data that cannot be lost
- Medium write frequency, high read frequency

**Use Cases**:
- User access tokens
- Session data
- User read status
- Important application state

## Why Multiple Valkey/Redis Instances?

### Problem 1: Conflicting Eviction Policies

**Single Valkey/Redis with multiple DBs**:
```yaml
# ❌ Problem: Global maxmemory-policy applies to ALL databases
redis:
  maxmemory: 2gb
  maxmemory-policy: allkeys-lru  # Applies to DB 0, 1, 2...
```

If you use `allkeys-lru`:
- ✅ Cache works well (can evict old data)
- ❌ **Sessions might be evicted** (users logged out unexpectedly!)
- ❌ **ActionCable channels evicted** (WebSocket connections broken!)

If you use `noeviction`:
- ✅ Sessions are safe
- ❌ **Cache fills up and stops accepting writes** (Valkey/Redis returns errors!)

**Multiple Valkey/Redis instances**:
```yaml
# ✅ Solution: Each instance has its own policy
redis_cache:
  maxmemory-policy: allkeys-lru   # Can evict
redis_session:
  maxmemory-policy: noeviction    # Cannot evict
```

### Problem 2: FLUSHDB Command Risks

**Single Valkey/Redis with multiple DBs**:
```ruby
# Intent: Clear Rails cache
Rails.cache.clear
# → Executes: FLUSHDB 0

# Risk: If you accidentally run FLUSHDB on wrong DB:
Redis.new.select(2)  # Oops, selected session DB
Redis.new.flushdb    # ❌ All user sessions gone!
```

**Multiple Valkey/Redis instances**:
```ruby
# ✅ Physically separate instances
REDIS_CACHE.with { |r| r.flushdb }    # Only cache affected
REDIS_SESSION.with { |r| r.flushdb }  # Completely separate
```

### Problem 3: Different Persistence Needs

**Single Valkey/Redis with multiple DBs**:
```yaml
# ❌ Problem: All DBs share same persistence settings
redis:
  appendonly: yes  # Slows down cache writes
  # OR
  save: ""  # Sessions not persisted (data loss on restart)
```

**Multiple Valkey/Redis instances**:
```yaml
# ✅ Solution: Optimized for each use case
redis_cache:
  save: ""                    # No persistence (fast writes)
redis_session:
  appendonly: yes             # Full persistence (data safety)
  appendfsync: everysec
```

### Problem 4: Independent Scaling

**Single Valkey/Redis**:
- Cannot scale cache without scaling sessions
- Cannot allocate more memory to cache independently
- All traffic shares same instance

**Multiple Valkey/Redis**:
- Scale cache Redis to 4GB if needed
- Keep session Redis at 512MB
- Distribute load across instances
- Add more cache replicas without affecting sessions

### Problem 5: Fault Isolation

**Single Valkey/Redis**:
- Cache issue → entire instance unresponsive
- Sessions, WebSocket, everything affected
- Single point of failure

**Multiple Valkey/Redis**:
- cache instance crash → **only cache affected**
- Sessions still work → **users stay logged in**
- ActionCable still works → **WebSocket connections intact**
- Application degrades gracefully

## Configuration Details

### redis_cache

```yaml
command: >
  redis-server
  --requirepass "$(cat /run/secrets/redis_cache_password)"
  --maxmemory 1gb
  --maxmemory-policy allkeys-lru
  --save ""
```

**Parameter Explanation**:
- `--maxmemory 1gb`: Maximum 1GB RAM usage
- `--maxmemory-policy allkeys-lru`: Evict least recently used keys when full
- `--save ""`: Disable RDB snapshots (no persistence)

**Why these settings**:
- Cache data is temporary and can be rebuilt
- LRU eviction ensures most frequently used data stays
- No persistence = faster write performance

### redis_cable

```yaml
command: >
  redis-server
  --requirepass "$(cat /run/secrets/redis_cable_password)"
  --maxmemory 512mb
  --maxmemory-policy noeviction
  --save ""
```

**Parameter Explanation**:
- `--maxmemory 512mb`: 512MB is enough for 1000+ concurrent WebSocket connections
- `--maxmemory-policy noeviction`: Return errors instead of evicting (pub/sub cannot lose messages)
- `--save ""`: No persistence (real-time data only)

**Why these settings**:
- Pub/sub messages are transient (once delivered, no longer needed)
- `noeviction` prevents message loss during high traffic
- 512MB handles most WebSocket scenarios

### redis_session

```yaml
command: >
  redis-server
  --requirepass "$(cat /run/secrets/redis_session_password)"
  --maxmemory 512mb
  --maxmemory-policy noeviction
  --appendonly yes
  --appendfsync everysec
```

**Parameter Explanation**:
- `--maxmemory 512mb`: 512MB can store ~50,000 user sessions
- `--maxmemory-policy noeviction`: Never evict user data
- `--appendonly yes`: Enable AOF (Append-Only File) for durability
- `--appendfsync everysec`: Sync to disk every second (balance safety/performance)

**Why these settings**:
- User sessions cannot be lost (critical data)
- AOF ensures data survives Redis restarts
- `everysec` provides good durability with minimal performance impact

## Memory Allocation

### Default Allocation

```
Total: 2GB
├─ redis_cache:   1GB   (50%)
├─ redis_cable:   512MB (25%)
└─ redis_session: 512MB (25%)
```

### When to Adjust

#### Increase cache Memory

**Scenario**: High cache miss rate, frequent DB queries

```yaml
redis_cache:
  maxmemory: 2gb  # Increase from 1GB
```

**Indicators**:
- Cache hit rate < 80%
- Database load is high
- Frequent cache evictions

#### Increase cable Memory

**Scenario**: Many concurrent WebSocket connections

```yaml
redis_cable:
  maxmemory: 1gb  # Increase from 512MB
```

**Indicators**:
- > 1000 concurrent WebSocket users
- Redis returning "OOM" errors
- Channels getting evicted (shouldn't happen with noeviction, but...)

#### Increase session Memory

**Scenario**: Many concurrent users, long session TTL

```yaml
redis_session:
  maxmemory: 1gb  # Increase from 512MB
```

**Indicators**:
- > 5000 concurrent users
- Redis returning "OOM" errors
- Need to store more session data per user

## Eviction Policies

### allkeys-lru (redis_cache)

**How it works**:
- Tracks when each key was last accessed
- Evicts least recently used keys when memory limit reached
- Keeps frequently accessed data in memory

**Best for**:
- Cache data
- Temporary data
- Data that can be rebuilt

**Example**:
```ruby
# First access
Rails.cache.write("user:1:profile", data, expires_in: 1.hour)

# If memory full and this key hasn't been accessed recently:
# → Key is evicted to make room for new data
```

### noeviction (redis_cable, redis_session)

**How it works**:
- Never evicts keys automatically
- Returns error when memory limit reached
- Application must handle errors

**Best for**:
- Critical data that cannot be lost
- Pub/sub channels
- User sessions

**Error handling**:
```ruby
begin
  REDIS_SESSION.with { |r| r.setex("token:#{token}", 3600, user_id) }
rescue Redis::CommandError => e
  if e.message.include?("OOM")
    # Handle out of memory
    # Options:
    # 1. Increase maxmemory
    # 2. Clean up old sessions
    # 3. Alert operators
    Rails.logger.error("Redis session OOM: #{e.message}")
  end
end
```

## Persistence Strategies

### No Persistence (redis_cache, redis_cable)

**Configuration**:
```yaml
--save ""  # Disable RDB snapshots
# No --appendonly flag
```

**Advantages**:
- Faster write performance (no disk I/O)
- Lower disk space usage
- Simpler operations (no AOF rewrites)

**Disadvantages**:
- Data lost on restart
- No disaster recovery

**Acceptable because**:
- Cache can be rebuilt from source
- WebSocket channels are transient (reconnect on restart)

### AOF Persistence (redis_session)

**Configuration**:
```yaml
--appendonly yes
--appendfsync everysec
```

**How it works**:
1. Every write command appended to AOF file
2. File synced to disk every second
3. On restart, Redis replays AOF to rebuild state

**Advantages**:
- Durability: Only ~1 second of data can be lost
- Crash recovery: Data survives Redis restarts
- Disaster recovery: Can copy AOF to another server

**Disadvantages**:
- Slightly slower writes (disk I/O)
- Larger disk space (AOF file grows)
- AOF rewrite needed periodically

**Trade-offs**:
```yaml
--appendfsync always    # Safest but slowest
--appendfsync everysec  # Good balance (recommended)
--appendfsync no        # Fastest but least safe
```

For user sessions, `everysec` is the sweet spot.

## Use Cases

### Rails.cache Examples

```ruby
# Query result caching
def expensive_report
  Rails.cache.fetch("report:monthly:#{Date.today}", expires_in: 1.day) do
    # 5 second query
    Order.where(created_at: 1.month.ago..Time.now).calculate_report
  end
end

# API response caching
def weather_data
  Rails.cache.fetch("weather:#{city}", expires_in: 30.minutes) do
    HTTParty.get("https://api.weather.com/#{city}")
  end
end

# Serialized object caching
def popular_products
  Rails.cache.fetch("products:popular", expires_in: 10.minutes) do
    Product.popular.limit(20).to_a  # Returns array of ActiveRecord objects
  end
end
```

All these use `redis_cache` automatically via `Rails.cache`.

### Access Token Authentication

```ruby
# Store token (use redis_session)
REDIS_SESSION.with do |redis|
  redis.setex(
    "token:#{token_value}",
    24.hours.to_i,
    { user_id: user.id, created_at: Time.now }.to_json
  )
end

# Verify token
REDIS_SESSION.with do |redis|
  data = redis.get("token:#{token_value}")
  JSON.parse(data) if data
end

# Revoke token (immediate effect)
REDIS_SESSION.with do |redis|
  redis.del("token:#{token_value}")
end
```

See `docs/AUTHENTICATION.md` for complete authentication architecture.

### ActionCable Broadcasting

```ruby
# Broadcast to user (uses redis_cable automatically)
ActionCable.server.broadcast(
  "notifications:#{user.id}",
  { message: "New order", order_id: 123 }
)

# The redis_cable instance handles pub/sub behind the scenes
# No manual Redis commands needed
```

## Monitoring

### Key Metrics

**redis_cache**:
```bash
redis-cli -p 6379 INFO stats
# Watch:
# - keyspace_hits, keyspace_misses (calculate hit rate)
# - evicted_keys (how many keys evicted)
# - used_memory (vs maxmemory)
```

**redis_cable**:
```bash
redis-cli -p 6380 INFO clients
# Watch:
# - connected_clients (concurrent WebSocket connections)
# - used_memory
# - pubsub_channels (active channels)
```

**redis_session**:
```bash
redis-cli -p 6381 INFO persistence
# Watch:
# - used_memory (approaching maxmemory?)
# - aof_current_size (AOF file size)
# - aof_last_rewrite_time_sec
```

### Health Checks

```ruby
# Check all Redis instances
def redis_health_check
  health = {}

  health[:cache] = REDIS_CACHE.with { |r| r.ping == "PONG" }
  health[:session] = REDIS_SESSION.with { |r| r.ping == "PONG" }
  # ActionCable health checked by Rails

  health
end
```

## Scaling Guide

### Stage 1: Single Server (< 1k users)

```
Current setup (default):
├─ redis_cache:   1GB
├─ redis_cable:   512MB
└─ redis_session: 512MB
```

**Sufficient for**:
- < 1000 concurrent users
- < 100 concurrent WebSocket connections
- < 10k requests/minute

### Stage 2: Optimize Memory (1k-10k users)

```yaml
# Increase memory allocation
redis_cache:
  maxmemory: 2gb      # More cache = fewer DB queries

redis_session:
  maxmemory: 1gb      # More sessions = more concurrent users
```

**Sufficient for**:
- 1k-10k concurrent users
- 100-1000 concurrent WebSocket connections
- 10k-100k requests/minute

### Stage 3: Add Replicas (10k-100k users)

```yaml
# Add read replicas for session Redis
redis_session_primary:
  maxmemory: 2gb

redis_session_replica1:
  replicaof: redis_session_primary 6379

redis_session_replica2:
  replicaof: redis_session_primary 6379

# Application reads from replicas, writes to primary
```

### Stage 4: Redis Cluster (100k+ users)

At this scale, consider:
- **Redis Cluster**: Automatic sharding across multiple nodes
- **Redis Sentinel**: Automatic failover
- **Managed Redis**: AWS ElastiCache, Google Memorystore, Azure Cache
- **Alternative**: AnyCable for WebSocket (replaces redis_cable)

## Alternative Architectures

### Option 1: Single Redis + Multiple DBs

```yaml
redis:
  maxmemory: 2gb
  maxmemory-policy: allkeys-lru  # ❌ Affects all DBs

# DB 0: Cache
# DB 1: Cable
# DB 2: Session
```

**Pros**:
- Simpler (1 container)
- Lower resource overhead

**Cons**:
- ❌ Same eviction policy for all
- ❌ Same persistence for all
- ❌ FLUSHDB risks
- ❌ Cannot scale independently

**When to use**: Development only

### Option 2: Managed Redis Service

```yaml
# AWS ElastiCache, Google Memorystore, etc.
redis_cache:
  endpoint: cache.redis.amazonaws.com:6379

redis_session:
  endpoint: session.redis.amazonaws.com:6379
```

**Pros**:
- High availability (automatic failover)
- Automatic backups
- Monitoring included
- Security patching handled

**Cons**:
- Monthly cost
- Vendor lock-in
- Network latency

**When to use**: Production at scale

### Option 3: Single Redis (Minimal)

```yaml
# Simplest possible setup
redis:
  maxmemory: 2gb
  maxmemory-policy: noeviction
  appendonly: yes
```

**Pros**:
- Extremely simple
- Low resource usage

**Cons**:
- ❌ Cache cannot evict (will error when full)
- ❌ Poor performance (persistence slows cache)
- ❌ No fault isolation

**When to use**: Only for prototypes/demos

## Troubleshooting

### Problem: redis_cache fills up

**Symptoms**:
```
Redis::CommandError: OOM command not allowed when used memory > 'maxmemory'
```

**Cause**: Cache is full and trying to write with `allkeys-lru` (shouldn't happen)

**Solutions**:
```bash
# 1. Check current memory usage
redis-cli -h redis_cache -p 6379 INFO memory

# 2. Increase maxmemory
# Edit compose.yaml: maxmemory 2gb

# 3. Or reduce TTL
Rails.cache.fetch("key", expires_in: 10.minutes)  # Shorter TTL
```

### Problem: redis_session out of memory

**Symptoms**:
```
Redis::CommandError: OOM command not allowed when used memory > 'maxmemory'
```

**Cause**: Too many sessions, maxmemory too low

**Solutions**:
```ruby
# 1. Clean up expired sessions
REDIS_SESSION.with do |redis|
  # Find and delete keys (be careful!)
  keys = redis.scan_each(match: "token:*").to_a
  expired = keys.select { |k| redis.ttl(k) == -1 }  # No TTL set
  expired.each { |k| redis.del(k) }
end

# 2. Increase maxmemory
# Edit compose.yaml: maxmemory 1gb

# 3. Reduce session TTL
REDIS_SESSION.with { |r| r.setex("token:#{token}", 12.hours, data) }  # Shorter
```

### Problem: ActionCable connections dropped

**Symptoms**: WebSocket connections randomly disconnect

**Possible causes**:
1. `redis_cable` out of memory
2. `redis_cable` restarted
3. Network issues

**Debug**:
```bash
# Check Redis cable health
redis-cli -h redis_cable -p 6379 INFO

# Check active channels
redis-cli -h redis_cable -p 6379 PUBSUB CHANNELS

# Check memory
redis-cli -h redis_cable -p 6379 INFO memory
```

**Solutions**:
```yaml
# Increase memory if needed
redis_cable:
  maxmemory: 1gb  # Double from 512MB
```

### Problem: redis_session data lost after restart

**Symptoms**: Users logged out after Redis restart

**Cause**: AOF not enabled or corrupted

**Solutions**:
```bash
# 1. Verify AOF is enabled
redis-cli -h redis_session -p 6379 CONFIG GET appendonly
# Should return: appendonly yes

# 2. Check AOF file exists
ls -lh .srv/redis_session/appendonly.aof

# 3. If corrupted, try repair
redis-check-aof --fix .srv/redis_session/appendonly.aof
```

---

## FAQ

### Q: Why do we have both REDIS_CACHE and Rails.cache? Aren't they redundant?

**A:** No, they serve different purposes.

#### Rails.cache (`:redis_cache_store`)

**Purpose: Daily caching operations**

```ruby
# High-level API
Rails.cache.fetch("user:#{id}:profile", expires_in: 1.hour) do
  User.find(id).profile
end

Rails.cache.read("key")
Rails.cache.write("key", value)
Rails.cache.delete("key")
```

**Features:**
- ✅ Automatically adds namespace (e.g., `rails:cache:user:1:profile`)
- ✅ High-level abstraction, easy to use
- ✅ Built-in error handling (error_handler callback)
- ✅ Supports marshal serialization of ActiveRecord objects
- ✅ Automatic connection pool management

**Use cases:**
- Fragment caching
- Query result caching
- API response caching
- Rack::Attack automatically uses it

#### REDIS_CACHE (ConnectionPool)

**Purpose: Direct Redis operations**

```ruby
# Low-level Redis native commands
REDIS_CACHE.with do |redis|
  redis.ping                    # Health check
  redis.info('memory')          # Monitor memory usage
  redis.keys('user:*')          # Debugging (avoid in production)
  redis.flushdb                 # Clear this Redis instance
  redis.get('custom_key')       # No namespace
end
```

**Features:**
- ✅ No namespace (direct access to raw keys)
- ✅ Complete Redis command set
- ✅ Used for health checks, monitoring
- ✅ Consistent API style with REDIS_SESSION, REDIS_CABLE

**Use cases:**
- Health checks (ping)
- Monitoring (INFO commands)
- Special needs (direct Redis operations)
- Clear specific Redis instance (without affecting others)

#### Key Point: Both use the **same Redis instance**

```ruby
# gem/redis.rb
cache_url = build_redis_url(...)  # redis://redis_cache:6379/0

# Rails.cache uses this URL
Rails.application.config.cache_store = :redis_cache_store, {
  url: cache_url,
  pool_size: pool_size  # ← Built-in connection pool
}

# REDIS_CACHE also uses the same URL
REDIS_CACHE = ConnectionPool.new(size: pool_size) do
  Redis.new(url: cache_url)
end
```

**No resource duplication:**
- ✅ Same Redis server (`redis_cache:6379`)
- ✅ Same pool size (both are `RAILS_MAX_THREADS`)
- ✅ Same data (just different access methods)

#### Usage Recommendations

```ruby
# ✅ Prefer Rails.cache (99% of cases)
Rails.cache.fetch("report:#{date}", expires_in: 1.hour) do
  generate_report(date)
end

# ✅ Use REDIS_CACHE for specific scenarios
# 1. Health checks
def redis_healthy?
  REDIS_CACHE.with { |r| r.ping == "PONG" }
end

# 2. Monitoring
def cache_memory_usage
  REDIS_CACHE.with { |r| r.info('memory') }
end

# 3. Clear specific Redis (without affecting session/cable)
def clear_cache_only
  REDIS_CACHE.with { |r| r.flushdb }  # Only clear cache, not session
end
```

#### Why can't we use only Rails.cache?

1. **Health checks need direct ping**
   ```ruby
   # ✅ Works
   REDIS_CACHE.with { |r| r.ping }

   # ❌ Rails.cache has no ping method
   Rails.cache.ping  # NoMethodError
   ```

2. **Monitoring needs INFO command**
   ```ruby
   # ✅ Works
   REDIS_CACHE.with { |r| r.info('stats') }

   # ❌ Rails.cache doesn't provide info
   Rails.cache.info  # NoMethodError
   ```

3. **Consistent API for multiple Valkey/Redis instances**
   ```ruby
   # Unified API style
   REDIS_CACHE.with   { |r| r.ping }  # Cache instance
   REDIS_SESSION.with { |r| r.ping }  # Session instance

   # If only Rails.cache, session API would be inconsistent
   ```

#### Why can't we use only REDIS_CACHE?

Rails ecosystem expects `Rails.cache` to exist:

```ruby
# Rack::Attack automatically uses Rails.cache
Rack::Attack.throttle('req/ip', limit: 100) { |req| req.ip }

# Fragment caching
<%= cache @product do %>
  <%= render @product %>
<% end %>

# ActiveRecord query cache
ActiveRecord::Base.cache do
  User.find(1)  # Cached query
end
```

If we only use REDIS_CACHE, we'd need to manually implement all these features.

#### RedisCacheStore internally uses connection_pool

Rails' `:redis_cache_store` **already uses** the `connection_pool` gem internally:

```ruby
# Rails source code (simplified)
class ActiveSupport::Cache::RedisCacheStore
  def initialize(options = {})
    pool_options = { size: options[:pool_size], timeout: options[:pool_timeout] }
    @redis = ::ConnectionPool.new(pool_options) do
      Redis.new(url: options[:url])
    end
  end
end
```

So actually:
- `Rails.cache` = `RedisCacheStore` (contains ConnectionPool)
- `REDIS_CACHE` = Manually created ConnectionPool

Both use the `connection_pool` gem, just for different purposes.

---

### Q: Why use three Valkey/Redis instances instead of one instance with multiple DBs?

**A:** Key reason: **eviction policy and persistence are Valkey/Redis instance-level settings**, cannot be configured per DB.

#### Problem: Single Valkey/Redis + multiple DBs

```yaml
# ❌ Problem configuration
redis:
  maxmemory: 2gb
  maxmemory-policy: allkeys-lru  # ← Applies to ALL DBs!
  appendonly: yes                 # ← Applies to ALL DBs!

# DB 0: Cache
# DB 1: Cable
# DB 2: Session
```

**Conflict 1: Eviction policy**
- Cache (DB 0) needs `allkeys-lru` (can evict old data)
- Session (DB 2) needs `noeviction` (cannot evict user data)
- ❌ **Cannot satisfy both!**

**Conflict 2: Persistence**
- Cache (DB 0) doesn't need persistence (cache can be rebuilt)
- Session (DB 2) needs AOF persistence (cannot lose user data)
- ❌ **Cannot satisfy both!**

#### Solution: Three independent Valkey/Redis instances

```yaml
# ✅ Each has independent configuration
redis_cache:
  maxmemory-policy: allkeys-lru
  save: ""  # No persistence

redis_session:
  maxmemory-policy: noeviction
  appendonly: yes  # Full persistence
```

See [Why Multiple Valkey/Redis Instances?](#why-multiple-valkeyredis-instances) section for details.

---

### Q: Can we use Memcached as cache instead?

**A:** Yes, but you'll lose some features.

#### Memcached Advantages

- ✅ Slightly faster (minimal difference)
- ✅ More stable memory usage
- ✅ Simpler (no persistence options)

#### Memcached Disadvantages

- ❌ No persistence (Redis has optional persistence)
- ❌ No data structures (Redis has SET, HASH, LIST, etc.)
- ❌ Cannot use for Rack::Attack (needs atomic INCR operation)
- ❌ Cannot use for ActionCable (needs pub/sub)
- ❌ Cannot use for session storage (needs persistence)

#### Conclusion

If you **only need simple key-value cache**, Memcached is an option:

```ruby
# config/environments/production.rb
config.cache_store = :mem_cache_store, "memcached:11211"
```

But this template needs:
- Rack::Attack rate limiting (needs INCR command)
- ActionCable WebSocket (needs pub/sub feature)
- Session storage (needs persistence)

So **Valkey/Redis is the better choice**.

---

### Q: Why does redis_cache use 1GB while redis_session only uses 512MB?

**A:** Adjusted based on typical usage patterns.

#### redis_cache: 1GB

**Stored content:**
- Query results (can be large)
- API responses (JSON, possibly several KB)
- Fragment caching (HTML fragments)
- Rate limiting counters (small but numerous)

**Characteristics:**
- Large data volume but can be evicted
- LRU automatically manages
- Larger is better (reduces cache miss)

#### redis_session: 512MB

**Stored content:**
- Access tokens (~100 bytes each)
- Session data (~1KB each)
- User state (small amount of data)

**Calculation:**
```
512MB ÷ 1KB/session = ~500,000 sessions
```

Sufficient for most applications.

#### redis_cable: 512MB

**Stored content:**
- Pub/sub channel metadata
- Active subscription info
- Real-time messages (transient)

**Characteristics:**
- Small data volume
- Only keeps active connections
- Messages can be discarded after delivery

#### Adjustment Recommendations

Adjust based on your application needs:

```yaml
# High-traffic API (large cache)
redis_cache:
  maxmemory: 4gb  # ↑

# Many concurrent users (long session TTL)
redis_session:
  maxmemory: 2gb  # ↑

# Many WebSocket (> 5000 concurrent)
redis_cable:
  maxmemory: 1gb  # ↑
```

---

## Summary

This template uses **Valkey by default** (100% Redis-compatible, fully open source) with **three separate instances** for:
1. **redis_cache**: Temporary data with LRU eviction
2. **redis_cable**: WebSocket pub/sub with no eviction
3. **redis_session**: Critical data with persistence

This architecture provides:
- ✅ Optimal performance for each use case
- ✅ Fault isolation
- ✅ Independent scaling
- ✅ Data safety where it matters
- ✅ Fully open source (BSD-3 license)

For most applications, this setup is **production-ready** and scales to thousands of concurrent users.

**Switching to Redis**: See [Switching to Redis](#switching-to-redis) if you need to use Redis instead of Valkey. It's a simple Docker image change with zero code modifications.

See also: [Authentication Guide](./AUTHENTICATION.md)
