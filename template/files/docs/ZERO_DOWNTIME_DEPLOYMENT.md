# Zero-Downtime Deployment: Complete Guide

## Table of Contents

- [Core Concepts](#core-concepts)
- [Backward Compatibility Principles](#backward-compatibility-principles)
- [Database Migration Strategies](#database-migration-strategies)
- [Application Deployment Strategies](#application-deployment-strategies)
- [Health Checks](#health-checks)
- [Graceful Shutdown](#graceful-shutdown)
- [Rollback Strategies](#rollback-strategies)
- [Common Pitfalls](#common-pitfalls)
- [Production Checklist](#production-checklist)

## Core Concepts

### What is Zero-Downtime Deployment?

Zero-downtime deployment is the practice of updating your application **without service interruption**, allowing users to experience no downtime during the deployment process.

### Why Do We Need Zero-Downtime Deployment?

```
Traditional Deployment (with downtime):
┌─────────────────────────────────────┐
│ T0: Stop old version                 │
│ T1: Deploy new version (5-10 mins)   │
│ T2: Start new version                │
│     ↓                                │
│ Users see: 503 Service Unavailable  │
└─────────────────────────────────────┘

Zero-Downtime Deployment:
┌─────────────────────────────────────┐
│ T0: Old version running              │
│ T1: Start new version (parallel)    │
│ T2: Switch traffic to new version   │
│ T3: Stop old version                 │
│     ↓                                │
│ Users: No interruption whatsoever   │
└─────────────────────────────────────┘
```

### Core Challenge

**New and old versions will run simultaneously for a period of time!**

```
Timeline:
┌─────────────────────────────────────────────────────────┐
│ T0: Old version running (V1)                             │
│ T1: Start deploying new version (V2)                     │
│     ├─ V1 containers still handling requests             │
│     └─ V2 containers starting up                         │
│ T2: V2 ready, starts receiving traffic                   │
│     ├─ V1 and V2 running simultaneously (⚠️ Critical)    │
│     └─ Load balancer gradually shifts traffic to V2      │
│ T3: V1 containers gracefully shutting down               │
│ T4: Only V2 running                                      │
└─────────────────────────────────────────────────────────┘
```

**Risks:**
- V1 reads old schema, V2 writes new schema → Data inconsistency
- V1 uses old column, V2 deleted that column → 500 error
- V1 expects old JSON format, V2 returns new format → Frontend crash

## Backward Compatibility Principles

### Golden Rule

**New versions must coexist harmoniously with old version data.**

### Examples: Wrong vs Correct

#### ❌ Wrong: Directly removing a column

```ruby
# Deployment 1: Remove email column
class RemoveEmailFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :email  # 💥 V1 still using it!
  end
end

# Result:
# V1 containers: SELECT email FROM users → Error! Column doesn't exist
# Users: 500 Internal Server Error
```

#### ✅ Correct: Phased approach

```ruby
# === Deployment 1: Add new field ===
class AddEmailAddressToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :email_address, :string
    add_index :users, :email_address

    # Copy existing data
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE users
          SET email_address = email
          WHERE email_address IS NULL AND email IS NOT NULL
        SQL
      end
    end
  end
end

# app/models/user.rb (Deployment 1)
class User < ApplicationRecord
  # Support both fields during transition
  def email
    email_address || read_attribute(:email)
  end

  def email=(value)
    self.email_address = value
    write_attribute(:email, value)  # Keep old field in sync
  end
end

# === Deployment 2: Switch to new field (wait 1-2 days) ===
# app/models/user.rb (Deployment 2)
class User < ApplicationRecord
  # Completely switch to email_address
  alias_attribute :email, :email_address
end

# === Deployment 3: Remove old field (wait 1-2 weeks) ===
class RemoveEmailFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :email  # Now it's safe
  end
end
```

## Database Migration Strategies

### Expand-Contract Pattern

**Three-phase strategy:**

```
Phase 1: Expand
├─ Add new column/table
├─ New and old columns coexist
└─ Code writes to both columns

Phase 2: Migrate
├─ Deploy new version
├─ Use new column
└─ Keep old column in sync (safety net)

Phase 3: Contract
├─ Confirm new version is stable
├─ Remove old column/code
└─ Cleanup complete
```

### Safe Migration Operations

| Operation | Risk Level | Zero-Downtime Strategy |
|---------|---------|-------------------|
| **ADD column (nullable)** | ✅ Safe | Execute directly |
| **ADD column (NOT NULL)** | ⚠️ Dangerous | Two steps: nullable first, then NOT NULL |
| **REMOVE column** | ❌ Dangerous | Expand-Contract (3 steps) |
| **RENAME column** | ❌ Dangerous | Expand-Contract (3 steps) |
| **ADD index** | ⚠️ Locks table | Use `algorithm: :concurrently` |
| **CHANGE column type** | ❌ Dangerous | Add new column + migrate data + remove old |
| **ADD foreign key** | ⚠️ Locks table | `validate: false` + manual validation |

### Real-World Cases

#### Case 1: Renaming a Column

```ruby
# === Phase 1: Expand (Deployment 1) ===
class AddFullNameToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :full_name, :string
    add_index :users, :full_name

    # Data migration (background, non-blocking)
    reversible do |dir|
      dir.up do
        User.find_each do |user|
          user.update_column(:full_name, user.name) if user.name.present?
        end
      end
    end
  end
end

# app/models/user.rb (Deployment 1)
class User < ApplicationRecord
  # Phase 1: Write to both fields
  before_save :sync_full_name

  def name
    full_name || read_attribute(:name)
  end

  def name=(value)
    self.full_name = value
    write_attribute(:name, value)
  end

  private

  def sync_full_name
    self.full_name = name if name_changed?
  end
end

# === Phase 2: Migrate (Deployment 2, wait 1-2 days) ===
# app/models/user.rb (Deployment 2)
class User < ApplicationRecord
  # Phase 2: Fully switch to full_name
  alias_attribute :name, :full_name

  # Remove sync logic (no longer needed)
end

# === Phase 3: Contract (Deployment 3, wait 1-2 weeks) ===
class RemoveNameFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :name
  end
end

# app/models/user.rb (Deployment 3)
class User < ApplicationRecord
  # Phase 3: Cleanup complete, only use full_name
end
```

#### Case 2: Adding a NOT NULL Column

```ruby
# ❌ Dangerous: Directly add NOT NULL
class AddRequiredFieldToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :phone, :string, null: false
    # 💥 V1 doesn't know about this field → INSERT fails!
  end
end

# ✅ Correct: Step-by-step approach
# Step 1: Add nullable column
class AddPhoneToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :phone, :string  # nullable
  end
end

# Step 2: Deploy code ensuring all new records have phone
# app/models/user.rb
class User < ApplicationRecord
  validates :phone, presence: true
end

# Step 3: Background job to backfill old data
# app/jobs/backfill_user_phone_job.rb
class BackfillUserPhoneJob < ApplicationJob
  def perform
    User.where(phone: nil).find_each do |user|
      user.update!(phone: generate_default_phone(user))
    end
  end
end

# Step 4: After confirming all data has phone, add NOT NULL constraint
class AddNotNullToUsersPhone < ActiveRecord::Migration[8.0]
  def change
    change_column_null :users, :phone, false
  end
end
```

#### Case 3: Concurrent Index Creation (PostgreSQL)

```ruby
# ❌ Wrong: Will lock table
class AddIndexToUsers < ActiveRecord::Migration[8.0]
  def change
    add_index :users, :email  # 💥 Locks table for seconds to minutes
  end
end

# ✅ Correct: No table lock
class AddIndexToUsers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!  # Required! CONCURRENTLY doesn't support transactions

  def change
    add_index :users, :email, algorithm: :concurrently
  end
end
```

#### Case 4: Changing Column Type

```ruby
# ❌ Dangerous: Directly change type
class ChangeUserAgeType < ActiveRecord::Migration[8.0]
  def change
    change_column :users, :age, :bigint  # 💥 Locks table + data conversion
  end
end

# ✅ Correct: Expand-Contract
# Step 1: Add new column
class AddAgeIntToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :age_int, :bigint

    # Copy data
    reversible do |dir|
      dir.up do
        execute "UPDATE users SET age_int = age::bigint WHERE age IS NOT NULL"
      end
    end
  end
end

# Step 2: Code uses new column
# app/models/user.rb
class User < ApplicationRecord
  def age
    age_int || read_attribute(:age)
  end

  def age=(value)
    self.age_int = value.to_i
    write_attribute(:age, value)
  end
end

# Step 3: Remove old column, rename new column
class RenameAgeIntToAge < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :age
    rename_column :users, :age_int, :age
  end
end
```

### Data Migration Best Practices

```ruby
# ❌ Wrong: Migrate large amounts of data in migration
class MigrateUserData < ActiveRecord::Migration[8.0]
  def change
    User.find_each do |user|
      user.update!(new_field: calculate_value(user))
    end
    # Problems:
    # 1. Migration takes too long (possibly hours)
    # 2. Blocks deployment process
    # 3. Cannot interrupt or rollback
    # 4. May timeout
  end
end

# ✅ Correct: Use background jobs
class AddNewFieldToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :new_field, :integer
    # Only add column, don't migrate data
  end
end

# app/jobs/migrate_user_data_job.rb
class MigrateUserDataJob < ApplicationJob
  queue_as :default

  def perform(batch_size: 1000)
    User.where(new_field: nil).find_in_batches(batch_size: batch_size) do |users|
      users.each do |user|
        user.update_column(:new_field, calculate_value(user))
      end

      sleep 0.1  # Avoid overloading database
    end
  end

  private

  def calculate_value(user)
    # Calculation logic
  end
end

# Trigger manually after deployment
# rails runner "MigrateUserDataJob.perform_later"

# Monitor progress
# User.where(new_field: nil).count
```

### Strong Migrations Gem

```ruby
# Gemfile
gem 'strong_migrations'

# config/initializers/strong_migrations.rb
StrongMigrations.start_after = 20250101000000  # Your starting migration timestamp

StrongMigrations.auto_analyze = true
StrongMigrations.target_version = 8.0

# Will automatically detect dangerous operations and provide suggestions
class RemoveEmailFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :email
    # StrongMigrations will raise error:
    # ActiveRecord::StrongMigrations::UnsafeMigration:
    # Removing a column is dangerous!
    #
    # Code referencing this column may still be in use.
    #
    # Suggestion: Use safety_assured and follow 3-step process
  end
end

# After following suggestions
class RemoveEmailFromUsers < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :users, :email }
    # Only use when confirmed safe (after Expand-Contract completed)
  end
end
```

## Application Deployment Strategies

### 1. Rolling Deployment

**Principle: Gradually replace old containers.**

```yaml
# Kubernetes example
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rails-app
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # At most 1 extra new pod (total 5)
      maxUnavailable: 0  # No pod can be unavailable (zero-downtime)
  template:
    spec:
      containers:
      - name: web
        image: myapp:v2
        ports:
        - containerPort: 3000
        livenessProbe:
          httpGet:
            path: /up
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /up
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Rolling update process:**

```
Initial state: 4 V1 pods
├─ Step 1: Start 1 V2 pod (maxSurge: 1)
│  └─ Wait for readinessProbe to pass
├─ Step 2: V2 pod ready, stop 1 V1 pod
│  └─ Now: 3 V1 + 1 V2 (total 4 available)
├─ Step 3: Start 2nd V2 pod
│  └─ Waiting for ready...
├─ Step 4: Stop 2nd V1 pod
│  └─ Now: 2 V1 + 2 V2
├─ Step 5-6: Repeat...
└─ Final: 4 V2 pods

✅ Always maintain 4 available pods (zero-downtime)
```

**Docker Compose notes:**

```yaml
# ❌ Docker Compose doesn't support zero-downtime rolling update
# docker compose restart web  # All containers restart simultaneously

# Solution: Manual rolling update
services:
  web:
    deploy:
      replicas: 4
      update_config:
        parallelism: 1      # Update 1 at a time
        delay: 10s          # 10 second delay between each
        order: start-first  # Start new before stopping old
```

### 2. Blue-Green Deployment

**Principle: Maintain two complete environments, instant switch.**

```
┌─────────────────────────────────────┐
│ Blue Environment (V1 - Currently)   │
│ ├─ 4 containers                     │
│ └─ Handling 100% traffic            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Green Environment (V2 - New)        │
│ ├─ 4 containers                     │
│ └─ 0% traffic (validating)          │
└─────────────────────────────────────┘

# After validation passes, switch traffic (instantaneous)
kubectl patch service rails-app -p '{"spec":{"selector":{"version":"v2"}}}'

# If issues occur, instant rollback
kubectl patch service rails-app -p '{"spec":{"selector":{"version":"v1"}}}'
```

**Advantages:**
- ✅ Extremely fast switching (seconds)
- ✅ Easy rollback
- ✅ Can fully test new environment

**Disadvantages:**
- ❌ Requires 2x resources
- ❌ Database migrations still need backward compatibility

### 3. Canary Deployment

**Principle: Gradual traffic increase, reducing risk.**

```
Stage 1: V2 receives 5% traffic (validation)
├─ Monitor error rate, latency
└─ Pass → Continue

Stage 2: V2 receives 25% traffic
├─ Continue monitoring
└─ Pass → Continue

Stage 3: V2 receives 50% traffic
├─ Continue monitoring
└─ Pass → Continue

Stage 4: V2 receives 100% traffic
└─ Deployment complete
```

**Kubernetes + Istio implementation:**

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: rails-app
spec:
  hosts:
  - rails-app
  http:
  - match:
    - headers:
        x-canary:
          exact: "true"
    route:
    - destination:
        host: rails-app
        subset: v2
  - route:
    - destination:
        host: rails-app
        subset: v1
      weight: 95  # V1: 95% traffic
    - destination:
        host: rails-app
        subset: v2
      weight: 5   # V2: 5% traffic
```

## Health Checks

### Rails 8 Built-in `/up` Endpoint

**Rails 8 includes a built-in health check route!** 🎉

```ruby
# Rails 8 automatically provides /up route (no additional setup)
# Controller: Rails::HealthController

# Features:
# ✅ Check if Rails app started successfully (no boot exceptions)
# ❌ Does NOT check database, Redis, or other external dependencies

# Response:
# 200 OK  - Application started normally
# 500     - Startup errors
```

**Use cases:**
- ✅ Docker healthcheck
- ✅ Kubernetes liveness probe
- ✅ Load balancer health check
- ✅ Basic application liveness detection

**When do you need custom health checks?**

If you need to check **external dependencies** (database, Redis, third-party APIs), you'll need a custom `HealthController`:

```ruby
# config/routes.rb
get '/health', to: 'health#index'  # Advanced health check

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :authenticate_user!  # Skip authentication

  def index
    checks = {
      database: check_database,
      redis_cache: check_redis(:cache),
      redis_session: check_redis(:session),
      redis_cable: check_redis(:cable)
    }

    all_healthy = checks.values.all? { |v| v == true }

    if all_healthy
      render json: { status: 'ok', checks: checks }, status: :ok
    else
      render json: { status: 'unhealthy', checks: checks }, status: :service_unavailable
    end
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1').any?
    true
  rescue StandardError => e
    { error: e.message }
  end

  def check_redis(type)
    pool = case type
           when :cache then REDIS_CACHE
           when :session then REDIS_SESSION
           when :cable then Redis.new(url: ENV['REDIS_CABLE_URL'])
           end

    pool.with { |r| r.ping == 'PONG' }
    true
  rescue StandardError => e
    { error: e.message }
  end
end
```

**Recommendations:**
- Basic deployment: Use built-in `/up` directly (sufficient!)
- Critical services: Custom `/health` to check external dependencies

### Liveness vs Readiness Probes

```yaml
# Kubernetes
containers:
- name: web
  # Liveness Probe: Check if alive
  # Failure → Restart container
  # Purpose: Detect deadlock, hang, and other serious issues
  livenessProbe:
    httpGet:
      path: /up
      port: 3000
    initialDelaySeconds: 30  # Wait 30 seconds after startup (give Rails time to boot)
    periodSeconds: 10        # Check every 10 seconds
    timeoutSeconds: 5        # 5 second timeout
    failureThreshold: 3      # Fail 3 times before marking unhealthy

  # Readiness Probe: Check if ready
  # Failure → Remove traffic (don't restart)
  # Purpose: Detect if ready to receive traffic
  readinessProbe:
    httpGet:
      path: /up
      port: 3000
    initialDelaySeconds: 5   # Start checking quickly
    periodSeconds: 5         # Check frequently
    timeoutSeconds: 3
    failureThreshold: 2      # Fail 2 times removes traffic
```

**Important distinction:**
- **Liveness**: "Is this container alive?" → Not alive → Restart
- **Readiness**: "Is this container ready to serve?" → Not ready → Pause traffic

### Health Check During Deployment

**Note:** Rails 8's built-in `/up` endpoint **returns 200 normally during migrations**, because it only checks if the app started, not migration status.

If you need health checks to fail during migrations (to avoid receiving traffic), there are two solutions:

**Solution 1: Use custom `/health` endpoint**

```ruby
# config/initializers/deployment_mode.rb
class DeploymentMode
  def self.migrating?
    File.exist?(Rails.root.join('tmp', 'migrating'))
  end

  def self.start_migration
    FileUtils.touch(Rails.root.join('tmp', 'migrating'))
  end

  def self.end_migration
    FileUtils.rm_f(Rails.root.join('tmp', 'migrating'))
  end
end

# config/routes.rb
get '/health', to: 'health#index'  # Deployment health check

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def index
    if DeploymentMode.migrating?
      render json: { status: 'migrating' }, status: :service_unavailable
      return
    end

    # Check dependencies...
    render json: { status: 'ok' }, status: :ok
  end
end

# docker-entrypoint.sh
if [ "$RAILS_DB_PREPARE" = "true" ]; then
  rails runner "DeploymentMode.start_migration"
  bundle exec rails db:prepare
  rails runner "DeploymentMode.end_migration"
fi

# compose.yaml - use /health instead of /up
healthcheck:
  test: ['CMD', 'curl', '-fsS', 'http://localhost:3000/health']
```

**Solution 2: Simplified approach (recommended for small projects)**

Stop receiving new traffic during migrations, let readiness probe fail:

```bash
# docker-entrypoint.sh
if [ "$RAILS_DB_PREPARE" = "true" ]; then
  # Create marker file
  touch /tmp/migrating

  bundle exec rails db:prepare

  # Remove marker file
  rm -f /tmp/migrating
fi

# healthcheck script
if [ -f /tmp/migrating ]; then
  exit 1  # Fail, stop receiving traffic
fi

curl -fsS http://localhost:3000/up
```

## Graceful Shutdown

### Puma Graceful Shutdown

Puma supports graceful shutdown by default:

```ruby
# config/puma.rb
worker_timeout ENV.fetch("PUMA_WORKER_TIMEOUT", 30).to_i

# Behavior when receiving SIGTERM:
# 1. Stop accepting new requests
# 2. Wait for existing requests to complete (up to worker_timeout seconds)
# 3. If timeout exceeded, force shutdown
# 4. Shutdown worker processes
```

### Docker Graceful Shutdown Configuration

```yaml
# compose.yaml
services:
  web:
    stop_signal: SIGTERM      # Send SIGTERM (Puma handles by default)
    stop_grace_period: 60s    # Give 60 seconds for graceful shutdown

    # If not shutdown within 60 seconds, Docker sends SIGKILL to force shutdown
```

### Kubernetes PreStop Hook

```yaml
containers:
- name: web
  lifecycle:
    preStop:
      exec:
        command:
        - /bin/sh
        - -c
        - |
          # 1. Wait for load balancer to stop sending new requests (give k8s time to update endpoints)
          sleep 5

          # 2. Send SIGTERM to Puma
          kill -SIGTERM 1

          # 3. Wait for Puma graceful shutdown (up to 30 seconds)
          sleep 30

  terminationGracePeriodSeconds: 60  # Total of 60 seconds
```

**Timeline:**
```
1. Kubernetes decides to stop pod
2. Execute preStop hook (sleep 5 + kill -SIGTERM + sleep 30)
3. Simultaneously: Remove pod from service endpoints
4. Wait terminationGracePeriodSeconds (60s)
5. If not finished, send SIGKILL force shutdown
```

### Background Job Graceful Shutdown

```ruby
# config/initializers/sidekiq.rb (if using Sidekiq)
Sidekiq.configure_server do |config|
  config.on(:shutdown) do
    # When receiving SIGTERM:
    # 1. Stop accepting new jobs
    # 2. Wait for running jobs to complete (up to 25 seconds)
    # 3. Shutdown
  end
end

# compose.yaml
services:
  worker:
    stop_grace_period: 30s  # Give Sidekiq enough time
```

## Rollback Strategies

### Application Rollback

```bash
# Kubernetes
kubectl rollout undo deployment/rails-app

# Check rollback status
kubectl rollout status deployment/rails-app

# Rollback to specific version
kubectl rollout history deployment/rails-app  # View history
kubectl rollout undo deployment/rails-app --to-revision=3
```

### Database Rollback Principles

**Important: Database migrations should usually NOT be rolled back!**

```ruby
# ❌ Dangerous: Rolling back migrations can cause data loss
rails db:rollback

# Example:
class AddUserPreferences < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :preferences, :jsonb
  end
end

# After deployment, users have set preferences
# Rollback → preferences column deleted → Data permanently lost!
```

**Correct approach:**

1. **Maintain backward compatibility**
   ```ruby
   # New version code can read old schema
   # Old version code can read new schema
   # → No need to rollback DB
   ```

2. **Only rollback application**
   ```bash
   # Rollback app code, keep DB schema
   kubectl rollout undo deployment/rails-app
   ```

3. **Exception: Safe to rollback migrations**
   ```ruby
   # Only "adding nullable column" can be safely rolled back
   class AddNewFieldToUsers < ActiveRecord::Migration[8.0]
     def change
       add_column :users, :new_field, :integer  # nullable
       # Can safely rollback (no data loss)
     end
   end
   ```

### Feature Flags

Used to quickly disable problematic features without redeployment:

```ruby
# Gemfile
gem 'flipper'
gem 'flipper-active_record'

# app/models/user.rb
class User < ApplicationRecord
  def can_use_new_feature?
    Flipper.enabled?(:new_feature, self)
  end
end

# app/controllers/api/v1/users_controller.rb
class Api::V1::UsersController < ApplicationController
  def show
    if current_user.can_use_new_feature?
      render json: V2::UserSerializer.new(@user)
    else
      render json: V1::UserSerializer.new(@user)
    end
  end
end

# After deployment, if issues found
# rails console
Flipper.disable(:new_feature)  # Immediately disable new feature, no redeployment needed
```

## Common Pitfalls

### 1. NOT NULL Constraint

```ruby
# ❌ Dangerous
class AddRequiredFieldToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :phone, :string, null: false
    # 💥 V1 INSERT users → Violates NOT NULL constraint
  end
end

# ✅ Correct: 4 steps
# Step 1: Add nullable column
add_column :users, :phone, :string

# Step 2: Deploy code (add validation)
validates :phone, presence: true

# Step 3: Background job to backfill old data
BackfillUserPhoneJob.perform_later

# Step 4: Add NOT NULL constraint
change_column_null :users, :phone, false
```

### 2. Enum Value Changes

```ruby
# ❌ Dangerous: Changing enum order
class User < ApplicationRecord
  enum status: [:active, :inactive, :pending]
  # V2 changes to: [:pending, :active, :inactive]
  # 💥 Database 0 was active, now becomes pending!
end

# ✅ Safe: Explicitly specify values
class User < ApplicationRecord
  enum status: {
    active: 0,
    inactive: 1,
    pending: 2
  }

  # V2 add new status
  enum status: {
    active: 0,
    inactive: 1,
    pending: 2,
    suspended: 3  # ✅ Safe: Only add, don't change existing values
  }
end
```

### 3. API Response Format Changes

```ruby
# ❌ Dangerous: Directly change JSON structure
# V1
def show
  render json: { user: { name: user.name } }
end

# V2 (after deployment)
def show
  render json: { data: { user: { name: user.name } } }
  # 💥 Frontend V1 code will crash: Cannot read user.name
end

# ✅ Safe: API versioning
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :users
  end

  namespace :v2 do
    resources :users
  end
end

# Or use Accept header
class UsersController < ApplicationController
  def show
    case request.headers['Accept-Version']
    when '2.0'
      render json: V2::UserSerializer.new(user)
    else
      render json: V1::UserSerializer.new(user)
    end
  end
end
```

### 4. Removing Index

```ruby
# ❌ Dangerous: Directly remove index
class RemoveIndexFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_index :users, :email
    # 💥 V1 queries become slow (dependent on this index)
  end
end

# ✅ Correct:
# 1. First deploy code that doesn't use this index
# 2. Monitor query performance
# 3. After confirming no issues, remove index
```

### 5. Foreign Key Constraint

```ruby
# ❌ Dangerous: Directly add foreign key
class AddForeignKeyToOrders < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :orders, :users
    # 💥 Locks table + validates all existing data (possibly minutes)
  end
end

# ✅ Safe: Two steps
# Step 1: Add foreign key but don't validate
class AddForeignKeyToOrders < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :orders, :users, validate: false
  end
end

# Step 2: Manual validation (no table lock)
class ValidateForeignKeyOnOrders < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :orders, :users
  end
end
```

## Monitoring and Alerting

### Key Metrics

Must monitor during deployment:

1. **Error Rate**
   - Target: < 0.1%
   - Exceeds threshold → Immediate rollback

2. **Response Time**
   - P95, P99 latency
   - Increase > 20% → Warning

3. **Database Connection Pool**
   - Connection count
   - Wait time

4. **Memory Usage**
   - Memory leak detection

5. **Request Rate**
   - QPS (Queries Per Second)
   - Traffic distribution (V1 vs V2)

### Monitoring Implementation Example

```ruby
# app/middleware/deployment_metrics.rb
class DeploymentMetrics
  def initialize(app)
    @app = app
  end

  def call(env)
    start = Time.now

    status, headers, body = @app.call(env)

    duration = Time.now - start

    # Report metrics (using StatsD/Datadog/Prometheus)
    StatsD.increment('requests.count', tags: ["version:#{APP_VERSION}"])
    StatsD.histogram('requests.duration', duration, tags: ["version:#{APP_VERSION}"])
    StatsD.increment('requests.status', tags: ["status:#{status}", "version:#{APP_VERSION}"])

    [status, headers, body]
  rescue StandardError => e
    StatsD.increment('requests.error', tags: ["error:#{e.class}", "version:#{APP_VERSION}"])
    raise
  end
end

# config/application.rb
config.middleware.use DeploymentMetrics
```

## Production Checklist

### Pre-Deployment Checklist

```markdown
□ Migration backward compatible?
  □ No remove_column
  □ No rename_column
  □ New columns are nullable
  □ Using algorithm: :concurrently for indexes
  □ Foreign keys using validate: false

□ Code backward compatible?
  □ API response format unchanged (or versioned)
  □ Enum values haven't changed order
  □ Background jobs compatible with old schema
  □ Model can read old column (transition period)

□ Health check configuration
  □ /up endpoint working normally
  □ Checking all dependent services (DB, Redis)
  □ readinessProbe configured correctly
  □ livenessProbe timeout sufficient

□ Graceful shutdown configuration
  □ stop_grace_period long enough (60s)
  □ Puma worker_timeout set correctly
  □ Background jobs have graceful shutdown

□ Monitoring configuration
  □ Error rate alerts set
  □ Response time alerts set
  □ Deployment dashboard ready
  □ Version tags correct (to distinguish V1/V2)

□ Rollback plan
  □ Rollback script prepared
  □ Feature flags can quickly disable new features
  □ Database doesn't depend on new schema (can rollback app)
  □ Team knows rollback process

□ Data migration (if any)
  □ Large data migrations use background jobs
  □ Has progress monitoring
  □ Can interrupt and re-execute
```

### During Deployment Monitoring

```markdown
□ Real-time monitoring
  □ Observe error rate (target: < 0.1%)
  □ Observe response time (P95, P99)
  □ Check database connection count
  □ Check memory usage

□ Traffic distribution
  □ V1 vs V2 traffic ratio
  □ New version gradually receives traffic

□ Log checking
  □ View Rails logs for anomalies
  □ View database slow query log
  □ View Redis connection status

□ User impact
  □ Frontend JavaScript errors
  □ API response time
  □ WebSocket connection status
```

### Post-Deployment Validation

```markdown
□ Smoke testing
  □ Main API endpoints normal
  □ Background jobs executing normally
  □ WebSocket connections normal
  □ Data writes normal

□ Performance metrics
  □ Error rate below baseline
  □ Response time below baseline
  □ Database queries normal
  □ Memory usage stable

□ Cleanup check
  □ Old pods/containers fully stopped
  □ Resource usage normal
  □ No leftover zombie processes

□ Long-term monitoring
  □ Monitor for 24 hours without anomalies
  □ Weekend/peak period validation
  □ Can start next phase (Contract phase)
```

## Summary

### Zero-Downtime Core Principles

1. **Backward compatibility is key**
   - New versions must coexist harmoniously with old versions
   - Use Expand-Contract pattern

2. **Phased deployment**
   - Database: Phase 1 (Expand) → Phase 2 (Migrate) → Phase 3 (Contract)
   - Application: Rolling/Blue-Green/Canary deployment

3. **Comprehensive health checks**
   - Liveness probe (alive)
   - Readiness probe (ready)

4. **Graceful shutdown**
   - Stop accepting new requests
   - Complete existing requests
   - Close connections

5. **Monitoring and rollback**
   - Real-time monitor key metrics
   - Rollback plan ready
   - Feature flags for quick disabling of new features

### Recommended Tools

- **strong_migrations**: Automatically detect dangerous migrations
- **flipper**: Feature flags
- **datadog/prometheus**: Monitoring and alerting
- **kubernetes**: Rolling deployment
- **istio**: Canary deployment

### Further Reading

- [Rails Guides - Migrations](https://guides.rubyonrails.org/active_record_migrations.html)
- [Strong Migrations](https://github.com/ankane/strong_migrations)
- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [The Twelve-Factor App](https://12factor.net/)
