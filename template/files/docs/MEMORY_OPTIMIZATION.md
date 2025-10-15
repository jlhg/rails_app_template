# Memory Optimization Guide

Memory management in Rails applications is critical for production environment performance. This guide covers memory optimization strategies, leak detection tools, and monitoring best practices.

## Table of Contents

- [Why Memory Optimization Matters](#why-memory-optimization-matters)
- [jemalloc Configuration](#jemalloc-configuration)
- [Memory Leak Detection](#memory-leak-detection)
- [Monitoring Best Practices](#monitoring-best-practices)
- [Common Memory Issues](#common-memory-issues)
- [Troubleshooting](#troubleshooting)
- [Alternative Solutions](#alternative-solutions)

## Why Memory Optimization Matters

### Typical Rails Application Memory Usage Pattern

```
At startup:
├─ Ruby VM:        ~50MB
├─ Rails framework: ~100MB
├─ Gems:           ~50MB
└─ Application:    ~50MB
   Total:          ~250MB

After running (no optimization):
├─ Worker 1:       2GB   ← Memory fragmentation
├─ Worker 2:       2GB
├─ Worker 3:       2GB
├─ Worker 4:       2GB
└─ Total:          8GB

After running (with jemalloc):
├─ Worker 1:       550MB ← Optimized
├─ Worker 2:       550MB
├─ Worker 3:       550MB
├─ Worker 4:       550MB
└─ Total:          2.2GB

Savings: ~75% memory usage
```

### Impact of Memory Issues

**Cost Impact:**
- AWS t3.large (8GB RAM): $60/month
- AWS t3.xlarge (16GB RAM): $120/month
- **After optimization can save 50% cloud costs**

**Performance Impact:**
- Out of memory → Swap → System slowdown
- OOM Killer → Container forced shutdown → Service interruption
- Frequent GC → Increased request latency

## jemalloc Configuration

### What is jemalloc?

jemalloc is a high-performance memory allocator developed by FreeBSD, optimized for multi-threaded applications.

**Why is it better than glibc malloc?**

| Feature | glibc malloc | jemalloc |
|---------|--------------|----------|
| Memory fragmentation | ⚠️ High (multi-threaded) | ✅ Low |
| Memory release | ❌ Slow (every 10 sec) | ✅ Fast (adjustable) |
| Arena management | ⚠️ Per-thread independent | ✅ Unified management |
| Multi-thread performance | ⚠️ Average | ✅ Excellent |

### Dockerfile Configuration (Built-in)

```dockerfile
FROM ruby:3.4-slim

# Enable jemalloc
RUN apt-get update && apt-get install -y libjemalloc2
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# Fine-tune jemalloc
ENV MALLOC_CONF="dirty_decay_ms:1000,narenas:2,background_thread:true"
```

### MALLOC_CONF Parameter Explanation

#### dirty_decay_ms (default: 10000)

**Purpose:** Controls how long to wait before releasing unused memory back to the OS

```bash
# Default 10 seconds (conservative)
MALLOC_CONF="dirty_decay_ms:10000"

# Recommended 1 second (aggressive release)
MALLOC_CONF="dirty_decay_ms:1000"

# Immediate release (most aggressive, may impact performance)
MALLOC_CONF="dirty_decay_ms:0"
```

**Recommendation:** Use `1000` (1 second) to balance performance and memory usage

#### narenas (default: 4 × CPU cores)

**Purpose:** Limit the number of memory arenas

```bash
# Default (8 core CPU = 32 arenas, too many!)
# Each arena ~64MB

# Recommended: 2-4 arenas (suitable for most applications)
MALLOC_CONF="narenas:2"

# Formula: narenas = CPU cores ÷ 2
# 2 core: narenas:1
# 4 core: narenas:2
# 8 core: narenas:4
```

**Recommendation:** Use `2` for 2-4 core containers

#### background_thread (default: false)

**Purpose:** Enable background thread for memory management

```bash
MALLOC_CONF="background_thread:true"
```

**Advantages:**
- ✅ Reduce main thread memory management overhead
- ✅ Faster memory release

**Disadvantages:**
- ⚠️ Additional CPU usage (minimal)

**Recommendation:** Enable

### Verify jemalloc is Active

```bash
# Method 1: Check environment variable
docker exec rails-app env | grep LD_PRELOAD
# Should output: LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# Method 2: Check process maps
docker exec rails-app cat /proc/1/maps | grep jemalloc
# Should see libjemalloc.so.2

# Method 3: Check in Ruby
docker exec rails-app rails runner "puts ENV['LD_PRELOAD']"
```

### jemalloc Statistics

```bash
# Get jemalloc stats (needs stats_print:true)
export MALLOC_CONF="stats_print:true"
docker exec rails-app rails runner "GC.start; sleep 1"

# Output will show detailed memory allocation statistics
```

## Memory Leak Detection

### Development Environment Tools

#### 1. memory_profiler

**Purpose:** Analyze memory allocation for specific code

```ruby
# Gemfile
group :development, :test do
  gem 'memory_profiler'
end

# Usage example
require 'memory_profiler'

report = MemoryProfiler.report do
  # Suspicious code
  1000.times do
    User.all.to_a  # ⚠️ Potential issue
  end
end

report.pretty_print

# Output:
# Total allocated: 150 MB
# Total retained:  10 MB
# allocated memory by gem
# ---------------------
# 100 MB  activerecord
#  30 MB  your_app
# ...
```

**Key metrics:**
- **allocated**: Total allocated memory (including temporary objects)
- **retained**: Retained memory (still exists after GC, potential leak)

#### 2. derailed_benchmarks

**Purpose:** Test memory usage of Rails endpoints

```ruby
# Gemfile
group :development, :test do
  gem 'derailed_benchmarks'
end

# Test endpoint memory growth
bundle exec derailed exec perf:mem_over_time

# Will repeatedly request endpoint and report memory usage
# If memory continues to grow → leak!

# Sample output:
# Endpoint: GET /users
# Request 1:  250 MB
# Request 10: 260 MB  ← Small increase (normal)
# Request 50: 450 MB  ← Continuous growth (leak!)
```

**Test specific endpoint:**

```bash
# Set path to test
export PATH_TO_HIT="/api/users"

# Test 100 requests
export TEST_COUNT=100

bundle exec derailed exec perf:mem_over_time
```

#### 3. Heap Dump Analysis

**Purpose:** In-depth analysis of object allocation

```ruby
# Generate heap dump
bundle exec derailed exec perf:heap_diff

# Will generate two heap dumps and compare differences
# Output files: heap_diff-before.dump, heap_diff-after.dump
```

**Analyze heap dump:**

```ruby
# Use heapy gem
gem install heapy

# Analyze dump
heapy read heap_diff-after.dump

# Find classes with most objects
# Sample output:
# Allocated by memory (bytes):
#   15 MB  String
#   10 MB  Array
#    5 MB  Hash
#    2 MB  User  ← Suspicious! Why so many User objects?
```

### Production Environment Monitoring

#### Prometheus + Grafana

**Key metrics:**

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'rails'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['rails-app:9394']
```

**Recommended metrics:**

```ruby
# config/initializers/prometheus.rb
require 'prometheus_exporter/instrumentation'

# Process metrics
PrometheusExporter::Instrumentation::Process.start(type: 'web')

# Custom memory metrics
gauge = PrometheusExporter::Client.default.register(
  :ruby_memory_usage_bytes,
  'Ruby process memory usage in bytes'
)

# Periodic updates
Thread.new do
  loop do
    gauge.observe(GC.stat[:heap_live_slots] * ObjectSpace::INTERNAL_CONSTANTS[:RVALUE_SIZE])
    sleep 30
  end
end
```

**Grafana Dashboard metrics:**

1. **Process RSS (Resident Set Size)**
   ```promql
   process_resident_memory_bytes{job="rails"}
   ```

2. **Heap live objects**
   ```promql
   ruby_gc_stat_heap_live_slots{job="rails"}
   ```

3. **GC frequency**
   ```promql
   rate(ruby_gc_stat_count{job="rails"}[5m])
   ```

4. **Memory growth rate**
   ```promql
   deriv(process_resident_memory_bytes{job="rails"}[1h])
   ```

#### AppSignal / NewRelic / Datadog

**Recommended alert rules:**

```yaml
# Memory growth alert
- name: Memory leak suspected
  condition: memory_growth_rate > 10MB/hour
  action: notify_team

# Absolute memory limit
- name: High memory usage
  condition: rss > 1.5GB
  action: restart_worker

# GC pressure
- name: Excessive GC
  condition: gc_time > 10% of request_time
  action: investigate
```

### Detection Process SOP

```
Step 1: Identify problem
├─ Symptom: Memory continuously growing
├─ Tool: Grafana dashboard
└─ Confirm: Not a temporary spike

Step 2: Isolate endpoint
├─ Use: derailed_benchmarks perf:mem_over_time
├─ Test: Each suspicious endpoint
└─ Identify: Which endpoint is leaking

Step 3: Analyze code
├─ Use: memory_profiler
├─ Check: retained objects
└─ Identify: Root cause

Step 4: Fix and verify
├─ Fix code
├─ Re-test: perf:mem_over_time
└─ Confirm: Memory stable
```

## Monitoring Best Practices

### Docker Memory Limits

```yaml
# compose.yaml
services:
  web:
    deploy:
      resources:
        limits:
          memory: 2G        # Hard limit (OOM killer if exceeded)
        reservations:
          memory: 512M      # Soft limit (minimum guaranteed)
    # Monitor memory usage
    healthcheck:
      test: ["CMD-SHELL", "test $(ps -o rss= -p 1) -lt 1800000 || exit 1"]
      # RSS < 1.8GB is healthy
```

### Puma Memory Monitoring

```ruby
# config/puma.rb
on_worker_boot do |index|
  # Log worker startup memory
  rss = `ps -o rss= -p #{Process.pid}`.to_i / 1024  # MB
  Rails.logger.info "Worker #{index} booted with RSS: #{rss}MB"
end

# Optional: Periodic memory logging
Thread.new do
  loop do
    sleep 60
    rss = `ps -o rss= -p #{Process.pid}`.to_i / 1024
    Rails.logger.info "Current RSS: #{rss}MB"
  end
end
```

### Key Alert Thresholds

| Metric | Warning | Critical | Action |
|------|------|------|------|
| Worker RSS | > 1GB | > 1.5GB | Check for leaks |
| Memory growth rate | > 5MB/hr | > 10MB/hr | Investigate immediately |
| GC time percentage | > 5% | > 10% | Optimize GC |
| Swap usage | > 100MB | > 500MB | Increase memory |

## Common Memory Issues

### 1. ActiveRecord Query Leaks

#### Problem: Loading all records

```ruby
# ❌ Memory leak
def export_users
  users = User.all.to_a  # Load 1 million records into memory!
  users.each do |user|
    CsvRow.create(user)
  end
end

# Memory usage: ~10GB (assuming 10KB per record)
```

#### Solution: Batch processing

```ruby
# ✅ Correct approach
def export_users
  User.find_each(batch_size: 1000) do |user|
    CsvRow.create(user)
    # Each batch 1000 records, memory usage ~10MB
  end
end

# Memory usage: Stable at ~50MB
```

### 2. N+1 Queries Leading to Object Accumulation

#### Problem:

```ruby
# ❌ N+1 query
def index
  @posts = Post.all
  # In view:
  # @posts.each { |post| post.author.name }
  # Queries author each time → generates many Author objects
end

# Memory usage: 1000 posts × (Post + Author) = many objects
```

#### Solution:

```ruby
# ✅ Eager loading
def index
  @posts = Post.includes(:author).all
  # Load all associations in one query
end

# Memory usage: Only necessary objects
```

### 3. Unlimited Cache

#### Problem: Manual cache

```ruby
# ❌ Memory leak
class UserService
  def initialize
    @cache = {}
  end

  def find_user(id)
    @cache[id] ||= User.find(id)
    # @cache grows forever!
  end
end

# After use: @cache contains all queried users
```

#### Solution: Use Rails.cache

```ruby
# ✅ Has TTL and eviction
class UserService
  def find_user(id)
    Rails.cache.fetch("user:#{id}", expires_in: 1.hour) do
      User.find(id)
    end
  end
end

# Rails.cache automatically cleans expired data
```

### 4. Circular References

#### Problem:

```ruby
# ❌ Circular reference
class Order
  def initialize
    @items = []
    @processor = OrderProcessor.new(self)  # self reference
  end
end

class OrderProcessor
  def initialize(order)
    @order = order  # Holds reference to order
  end
end

# Order → OrderProcessor → Order (cycle)
# GC cannot reclaim (Ruby 2.x)
```

#### Solution:

```ruby
# ✅ Use WeakRef or break cycle
require 'weakref'

class Order
  def initialize
    @items = []
    # Don't create processor in initialize
  end

  def process
    OrderProcessor.new.process(self)  # Temporary association
  end
end
```

### 5. String Accumulation

#### Problem:

```ruby
# ❌ String concatenation
def generate_csv
  csv = ""
  User.find_each do |user|
    csv += "#{user.id},#{user.name}\n"  # Creates new String each time!
  end
  csv
end

# Each += creates new String object
# 1 million records = 1 million temporary String objects
```

#### Solution:

```ruby
# ✅ Use StringIO or Array
def generate_csv
  require 'stringio'
  csv = StringIO.new

  User.find_each do |user|
    csv << "#{user.id},#{user.name}\n"  # In-place modification
  end

  csv.string
end

# Or use Array
def generate_csv
  lines = []
  User.find_each do |user|
    lines << "#{user.id},#{user.name}"
  end
  lines.join("\n")
end
```

### 6. Uncleaned Background Jobs

#### Problem:

```ruby
# ❌ Job holds large amounts of data
class ReportJob < ApplicationJob
  def perform
    @users = User.all.to_a  # Load all
    @orders = Order.all.to_a
    generate_report
    # Job completes but objects still in memory
  end
end
```

#### Solution:

```ruby
# ✅ Explicitly release
class ReportJob < ApplicationJob
  def perform
    process_users
    process_orders
    generate_report
  ensure
    # Explicit cleanup
    @users = nil
    @orders = nil
    GC.start  # Suggest GC (not guaranteed immediate execution)
  end

  private

  def process_users
    User.find_each do |user|
      # Process each user
    end
    # user objects can be GC'd after block ends
  end
end
```

## Troubleshooting

### Problem: Memory Continuously Growing

**Symptoms:**
```
Worker RSS:
T0:  250 MB  (startup)
T1:  400 MB  (1 hour)
T2:  550 MB  (2 hours)
T3:  700 MB  (3 hours)
T4:  850 MB  (4 hours)
...
```

**Diagnosis:**

```bash
# 1. Confirm if it's a memory leak
# Use derailed_benchmarks to test endpoints
export PATH_TO_HIT="/api/users"
bundle exec derailed exec perf:mem_over_time

# 2. Generate heap dump
bundle exec derailed exec perf:heap_diff

# 3. Analyze retained objects
heapy read heap_diff-after.dump | grep -A20 "Retained"
```

**Common causes:**

1. **ActiveRecord not eager loading**
   ```ruby
   # Check logs for N+1 queries
   # Use bullet gem
   ```

2. **Unlimited cache growth**
   ```ruby
   # Search for @instance_variables
   # Ensure no unlimited Hash/Array
   ```

3. **EventMachine / async library leaks**
   ```ruby
   # Check if callbacks are cleaned up correctly
   ```

### Problem: OOM Killer Frequently Triggered

**Symptoms:**
```
[12345.678] Out of memory: Kill process 1234 (ruby) score 900 or sacrifice child
```

**Diagnosis:**

```bash
# 1. Check Docker memory limits
docker inspect rails-app | grep -A10 Memory

# 2. Check actual memory usage
docker stats rails-app

# 3. View dmesg
dmesg | grep -i "out of memory"
```

**Solutions:**

1. **Increase memory limits**
   ```yaml
   deploy:
     resources:
       limits:
         memory: 4G  # Increase from 2G
   ```

2. **Enable swap (temporary)**
   ```yaml
   deploy:
     resources:
       limits:
         memory: 2G
       reservations:
         memory: 512M
   # Allow using swap (performance will decrease)
   ```

3. **Reduce Puma workers**
   ```ruby
   # Reduce from 4 workers to 2
   workers ENV.fetch("WEB_CONCURRENCY", 2)
   ```

### Problem: GC Taking Too Long

**Symptoms:**
```
Request time: 200ms
GC time:      50ms  (25% of time in GC!)
```

**Diagnosis:**

```ruby
# Check GC statistics
GC.stat
# Focus on:
# - count: GC times
# - heap_live_slots: live object count
# - heap_free_slots: available slots
# - major_gc_count: Major GC count (expensive)
```

**Solutions:**

1. **Adjust GC parameters**
   ```ruby
   # config/boot.rb
   if ENV['RAILS_ENV'] == 'production'
     # Increase heap slots (reduce GC frequency)
     GC::Profiler.enable
     GC.stat[:heap_init_slots] = 600_000

     # Adjust GC malloc limit
     GC.stat[:malloc_increase_bytes_limit] = 64_000_000
   end
   ```

2. **Use jemalloc** (already in Dockerfile)

3. **Reduce object allocation**
   ```ruby
   # ❌ Allocate new String each time
   def greet(name)
     "Hello, #{name}!"
   end

   # ✅ Use frozen string
   GREETING_PREFIX = "Hello, "
   def greet(name)
     "#{GREETING_PREFIX}#{name}!"
   end
   ```

### Problem: Memory Fragmentation

**Symptoms:**
```
RSS:    1.5 GB
Heap:   800 MB
Fragmentation: 700 MB (47%)
```

**Cause:**
- glibc malloc's poor arena management
- Frequent small object allocation/deallocation

**Solution:**
- ✅ **Use jemalloc** (already configured)
- jemalloc has better arena management, fragmentation < 10%

### Problem: jemalloc Not Active

**Symptoms:**
```bash
ps aux | grep ruby
# RSS still high, similar to without jemalloc situation
```

**Diagnosis:**

```bash
# Check LD_PRELOAD
docker exec rails-app env | grep LD_PRELOAD

# Check library loading
docker exec rails-app cat /proc/1/maps | grep jemalloc
```

**Solutions:**

1. **Confirm libjemalloc2 is installed**
   ```bash
   docker exec rails-app dpkg -l | grep jemalloc
   ```

2. **Check path is correct**
   ```bash
   docker exec rails-app ls -l /usr/lib/x86_64-linux-gnu/libjemalloc.so.2
   ```

3. **Rebuild image**
   ```bash
   docker compose build --no-cache web
   ```

## Alternative Solutions

### Option 1: Alpine + MALLOC_ARENA_MAX (Not Recommended)

If you must use Alpine (e.g., extreme image size requirements):

```dockerfile
FROM ruby:3.4-alpine

# Use MALLOC_ARENA_MAX instead of jemalloc
# Less effective but better than nothing (saves about 30-40% memory)
ENV MALLOC_ARENA_MAX=2

# Other configuration...
```

**Advantages:**
- ✅ Smaller image size (~100MB vs ~220MB)
- ✅ Simple configuration

**Disadvantages:**
- ❌ Less memory optimization (30-40% vs 75%)
- ❌ Still has memory fragmentation issues
- ❌ Poorer multi-thread performance

**Use cases:**
- Development/testing environments
- Strict image size limits
- Low-traffic applications

### Option 2: Puma Worker Killer (Temporary Solution)

**Warning: This is a band-aid, not a solution!**

```ruby
# Gemfile
gem 'puma_worker_killer'

# config/puma.rb
before_fork do
  require 'puma_worker_killer'

  PumaWorkerKiller.enable_rolling_restart(
    3 * 60 * 60,  # Restart worker every 3 hours
    10            # ±10 minutes variance
  )
end
```

**When to use:**
- ✅ As temporary measure (while fixing real leaks)
- ✅ Known slow leak but hard to fix

**Why not recommended as long-term solution:**
- ❌ Doesn't solve root problem
- ❌ Restarting workers interrupts in-progress requests
- ❌ Wastes resources (repeated startup)

### Option 3: Reduce Puma Workers

```ruby
# config/puma.rb
# Reduce from 4 workers to 2 workers
workers ENV.fetch("WEB_CONCURRENCY", 2)

# Increase threads to compensate
max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 32).to_i
```

**Advantages:**
- ✅ Reduce total memory usage (2 × 1GB vs 4 × 1GB)
- ✅ Reduce database connection count

**Disadvantages:**
- ❌ Lower concurrent processing capability
- ❌ Not suitable for CPU-intensive applications

**Use cases:**
- I/O intensive applications
- Strict memory constraints

## Production Environment Checklist

Pre-deployment confirmation:

```markdown
□ Memory Optimization
  □ Using Debian + jemalloc (not Alpine)
  □ LD_PRELOAD correctly set
  □ MALLOC_CONF adjusted
  □ Verify jemalloc is active

□ Docker Configuration
  □ memory limits set (2-4GB)
  □ healthcheck includes memory check
  □ Logs output correctly

□ Puma Configuration
  □ Reasonable workers count (2-4)
  □ Reasonable threads count (16-32)
  □ preload_app! enabled

□ Monitoring Setup
  □ Prometheus/Grafana or APM tool
  □ Memory alerts set
  □ Memory dashboard created

□ Code Review
  □ No obvious N+1 queries
  □ Batch processing uses find_each
  □ Cache uses Rails.cache (has TTL)
  □ No circular references

□ Testing
  □ Run derailed_benchmarks
  □ Load testing (memory stable)
  □ Memory leak testing passed
```

---

## Summary

### Key Takeaways

1. **Use jemalloc**
   - Most important optimization (75% memory savings)
   - Already configured in Dockerfile

2. **Monitoring is key**
   - Set up Prometheus metrics
   - Set alert thresholds
   - Regularly check dashboard

3. **Prevention is better than cure**
   - Code review checks for memory issues
   - Use find_each instead of all
   - Use Rails.cache instead of manual cache

4. **Toolbox**
   - Development: memory_profiler, derailed_benchmarks
   - Production: Prometheus, APM tools
   - Troubleshooting: heap dumps, GC.stat

### Further Reading

- [Ruby Memory Optimization](https://www.speedshop.co/2017/12/04/malloc-doubles-ruby-memory.html)
- [jemalloc Documentation](https://jemalloc.net/)
- [Puma Performance Guide](https://github.com/puma/puma/blob/master/docs/kubernetes.md)
- [derailed_benchmarks](https://github.com/zombocom/derailed_benchmarks)

### Related Documentation

- [REDIS_ARCHITECTURE.md](./REDIS_ARCHITECTURE.md) - Redis memory configuration
- [ZERO_DOWNTIME_DEPLOYMENT.md](./ZERO_DOWNTIME_DEPLOYMENT.md) - Deployment best practices
