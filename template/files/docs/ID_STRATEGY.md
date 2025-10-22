# Resource ID Strategy Guide

This document explains the ID (identifier) strategy for database primary keys in this Rails API template, focusing on security, performance, and best practices.

## Table of Contents

- [Overview](#overview)
- [Why Not Use Auto-Incrementing IDs?](#why-not-use-auto-incrementing-ids)
- [UUIDv7: The Recommended Solution](#uuidv7-the-recommended-solution)
- [Performance Comparison](#performance-comparison)
- [Implementation](#implementation)
- [Alternatives Comparison](#alternatives-comparison)
- [Best Practices](#best-practices)
- [Migration Guide](#migration-guide)
- [FAQ](#faq)

## Overview

This template uses **UUIDv7** as the default primary key type for all database tables. This decision balances security, performance, and developer experience.

```
┌─────────────────────────────────────────────────────────────┐
│                     ID Type Comparison                       │
├──────────────┬──────────┬──────────────┬────────────────────┤
│ Type         │ Size     │ Insert (1M)  │ Security           │
├──────────────┼──────────┼──────────────┼────────────────────┤
│ bigint       │ 8 bytes  │ 290 seconds  │ ❌ Leaks business  │
│ UUIDv7       │ 16 bytes │ 290 seconds  │ ✅ Secure          │
│ UUIDv4       │ 16 bytes │ 375 seconds  │ ✅ Secure          │
│ ULID         │ 16 bytes │ ~290 seconds │ ✅ Secure          │
└──────────────┴──────────┴──────────────┴────────────────────┘

✅ UUIDv7 = bigint performance + UUID security
```

## Why Not Use Auto-Incrementing IDs?

### Business Intelligence Leakage

Using sequential integer IDs exposes sensitive business information:

```ruby
# ❌ Problem: Using bigint auto-increment
GET /api/orders/12345
# → Reveals: "This company has ~12,345 orders"

GET /api/orders/12345  # Today
GET /api/orders/12850  # One week later
# → Reveals: "They're getting ~500 orders/week"
```

**Real-world risks**:
- 📊 Competitors can estimate your business scale
- 📈 Anyone can track your growth/decline rate
- 🔍 Enumeration attacks (try ID 1, 2, 3...)
- 🕵️ Infer temporal relationships between resources

### Enumeration Attacks

Even with proper authorization, sequential IDs leak information:

```ruby
# Attacker tries sequential IDs
GET /api/orders/1     # 403 Forbidden (exists, not authorized)
GET /api/orders/2     # 403 Forbidden (exists, not authorized)
GET /api/orders/500   # 404 Not Found (doesn't exist)

# → Attacker knows: "There are ~500 orders in the system"
```

## UUIDv7: The Recommended Solution

### What is UUIDv7?

UUIDv7 is a **time-ordered UUID** standardized in [RFC 9562](https://datatracker.ietf.org/doc/rfc9562/):

```
UUIDv7 Structure (128 bits total):
┌────────────────┬──────────────┬─────────────────────┐
│   48 bits      │   12 bits    │    68 bits          │
│   Unix Time    │   Subsec     │    Random           │
│   (ms)         │   Precision  │                     │
└────────────────┴──────────────┴─────────────────────┘

Example: 018f4d9e-5c4a-7000-9f8b-3a4c5d6e7f8a
         └─────┬─────┘
           Time portion (sortable)
```

**Key properties**:
- ✅ **Time-ordered**: Naturally sorted by creation time
- ✅ **Random**: 68 random bits prevent prediction
- ✅ **Unique**: Globally unique (no collisions)
- ✅ **Standard**: RFC 9562 (supported by PostgreSQL 18+, MySQL 8.4+)

### Why UUIDv7 is Perfect for Rails 8 + PostgreSQL 18

1. **Native database support** (PostgreSQL 18+)
   ```sql
   CREATE TABLE orders (
     id UUID PRIMARY KEY DEFAULT uuidv7(),
     created_at TIMESTAMP NOT NULL
   );
   ```

2. **Same performance as bigint**
   - Time-ordered structure = excellent B-tree locality
   - Inserts at end of index (like auto-increment)
   - No random page splits (unlike UUIDv4)

3. **Security without performance cost**
   - Prevents business intelligence leakage
   - Unpredictable (68 random bits)
   - Still sortable by time

## Performance Comparison

### Benchmark Data (1 Million Row Insert)

| ID Type | Insert Time | Relative | Index Size |
|---------|-------------|----------|------------|
| **bigint** | 290 sec | 100% (baseline) | 21 MB |
| **UUIDv7** | 290 sec | **100%** ✅ | 43 MB |
| UUIDv4 | 375 sec | 77% | 49 MB |
| Text UUID | 410 sec | 71% | 65 MB |

**Source**: [PostgreSQL UUID Performance Benchmark (2025)](https://dev.to/umangsinha12/postgresql-uuid-performance-benchmarking-random-v4-and-time-based-v7-uuids-n9b)

### Why UUIDv7 = bigint Performance?

```
bigint (sequential):
┌──────────────────────────────────┐
│ B-tree Index                     │
│ [...994][995][996][997][998]     │◄── Always insert here
│                           ▲      │
│                           └──────┼── New values
└──────────────────────────────────┘

UUIDv7 (time-ordered):
┌──────────────────────────────────┐
│ B-tree Index                     │
│ [...018f-4d9e][018f-4d9f][...]   │◄── Always insert here
│                           ▲      │    (time increases)
│                           └──────┼── New UUIDs
└──────────────────────────────────┘

UUIDv4 (random):
┌──────────────────────────────────┐
│ B-tree Index                     │
│ [a7..][c2..]...[5f..][z9..]      │
│    ▲      ▲           ▲          │
│    └──────┴───────────┴──────────┼── Random inserts (slow!)
└──────────────────────────────────┘
```

**Key insight**: UUIDv7's time-ordered structure provides the same B-tree append-only behavior as sequential bigint, avoiding expensive page splits.

## Implementation

### Default Configuration

This template configures all new tables to use UUIDv7 automatically:

```ruby
# config/initializers/generators.rb (auto-generated)
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

### Generated Migrations

When you run `rails g model Order`, the migration uses UUIDs:

```ruby
# db/migrate/20250122_create_orders.rb
class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders, id: :uuid do |t|
      t.references :user, type: :uuid, foreign_key: true
      t.string :status
      t.decimal :total
      t.timestamps
    end
  end
end
```

**Generated SQL**:
```sql
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuidv7(),  -- ✅ Uses PostgreSQL 18's native uuidv7()
  user_id UUID NOT NULL,
  status VARCHAR,
  total NUMERIC,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

### Model Usage

No special code needed in models:

```ruby
class Order < ApplicationRecord
  belongs_to :user
end

# Works exactly like integer IDs:
order = Order.create(user: current_user, status: 'pending')
order.id  # => "018f4d9e-5c4a-7000-9f8b-3a4c5d6e7f8a"

# Finding works the same:
Order.find("018f4d9e-5c4a-7000-9f8b-3a4c5d6e7f8a")

# URL generation:
order_url(order)  # => "https://api.example.com/orders/018f4d9e-5c4a-7000-9f8b-3a4c5d6e7f8a"
```

### Selective Opt-Out (Using bigint)

For internal tables where security doesn't matter:

```ruby
# Use bigint for join tables, audit logs, etc.
create_table :active_storage_blobs, id: :bigint do |t|
  # Internal table, no security concern
end

create_table :orders_products, id: :bigint do |t|
  # Join table, not exposed via API
  t.references :order, type: :uuid, foreign_key: true
  t.references :product, type: :uuid, foreign_key: true
end
```

## Alternatives Comparison

### UUIDv7 vs UUIDv4

| Feature | UUIDv4 | UUIDv7 |
|---------|--------|--------|
| Performance | ❌ 77% (random inserts) | ✅ 100% (time-ordered) |
| Security | ✅ Unpredictable | ✅ Unpredictable |
| Sortable | ❌ No meaning | ✅ By creation time |
| Standard | ✅ RFC 4122 | ✅ RFC 9562 |
| DB Support | PostgreSQL 13+ | PostgreSQL 18+ |

**Verdict**: Always use UUIDv7 over UUIDv4 (if on PostgreSQL 18+).

### UUIDv7 vs ULID

| Feature | ULID | UUIDv7 |
|---------|------|--------|
| Performance | ✅ ≈ 100% | ✅ 100% |
| Security | ✅ Unpredictable | ✅ Unpredictable |
| Structure | 48-bit time + 80-bit random | 48-bit time + 68-bit random |
| Format | 26 chars (Base32) | 36 chars (hex + dashes) |
| DB Native | ❌ Needs extension/gem | ✅ PostgreSQL 18+ native |
| Standard | ❌ Community spec | ✅ RFC 9562 |

**ULID encoding**: `01ARZ3NDEKTSV4RRFFQ69G5FAV` (26 characters)
**UUIDv7 encoding**: `018f4d9e-5c4a-7000-9f8b-3a4c5d6e7f8a` (36 characters)

**Verdict**: UUIDv7 is better for PostgreSQL 18+ projects due to native support. ULID is useful if you need shorter URLs or support older PostgreSQL versions.

### When to Use bigint

| Scenario | Recommended | Reason |
|----------|-------------|--------|
| Public API resources (orders, users) | ✅ UUIDv7 | Security critical |
| Internal tables (logs, metrics) | ⚠️ bigint | No exposure risk |
| Join tables | ⚠️ bigint | Not directly accessible |
| High-write tables (events, analytics) | ⚠️ bigint | Smaller storage |
| Distributed systems | ✅ UUIDv7 | Global uniqueness |

## Best Practices

### 1. Always Use Authorization (Defense in Depth)

UUIDs provide security through obscurity, but **always implement proper authorization**:

```ruby
# ❌ Wrong: Relying only on UUID secrecy
class OrdersController < ApplicationController
  def show
    @order = Order.find(params[:id])  # Anyone with UUID can access!
  end
end

# ✅ Correct: UUID + authorization
class OrdersController < ApplicationController
  def show
    @order = current_user.orders.find(params[:id])  # Scoped to user
  end
end

# ✅ Better: UUID + Pundit
class OrdersController < ApplicationController
  def show
    @order = Order.find(params[:id])
    authorize @order  # Pundit policy check
  end
end
```

### 2. Sensitive Resources = UUID

| Resource Type | ID Type | Rationale |
|--------------|---------|-----------|
| Users, Orders, Invoices, Payments | UUIDv7 | High sensitivity |
| Blog posts, Categories, Tags | bigint or UUIDv7 | Public info, less critical |
| Admin-only resources | bigint | Not exposed to users |

### 3. Index Foreign Keys

UUIDs are larger (16 bytes vs 8 bytes), so indexing is important:

```ruby
# Always index UUID foreign keys
create_table :orders, id: :uuid do |t|
  t.references :user, type: :uuid, foreign_key: true, index: true  # ✅
end

# Compound indexes when needed
add_index :orders, [:user_id, :status]  # For queries like: user.orders.where(status: 'pending')
```

### 4. Display Format

UUIDs are long in URLs. Consider using shortened formats if needed:

```ruby
# Option A: Use full UUID (recommended, standard)
# /api/orders/018f4d9e-5c4a-7000-9f8b-3a4c5d6e7f8a

# Option B: Remove dashes for cleaner URLs
class Order < ApplicationRecord
  def to_param
    id.delete('-')  # 018f4d9e5c4a70009f8b3a4c5d6e7f8a
  end

  def self.find_by_param(param)
    # Re-add dashes for lookup
    uuid = param.scan(/.{8}|.{4}/).join('-')
    find(uuid)
  end
end

# Option C: Use Hashids for short URLs (adds complexity)
# See HASHIDS.md for implementation details
```

## Migration Guide

### Adding UUIDs to Existing Project

If you have an existing Rails project with integer IDs:

#### Step 1: Add UUID Extension (if needed)

```ruby
# db/migrate/20250122_enable_uuid_extension.rb
class EnableUuidExtension < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
  end
end
```

#### Step 2: Create New Table with UUIDs

```ruby
# New tables use UUIDs from the start
class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders, id: :uuid do |t|
      t.references :user, type: :bigint, foreign_key: true  # ⚠️ Old users table uses bigint
      t.timestamps
    end
  end
end
```

#### Step 3: Migrating Existing Tables (Advanced)

**Warning**: Migrating existing tables from bigint to UUID is **complex** and **risky**. Only do this if absolutely necessary.

```ruby
# NOT RECOMMENDED for production data
# Requires downtime and careful planning
class MigrateUsersToUuid < ActiveRecord::Migration[8.0]
  def up
    # 1. Add UUID column
    add_column :users, :uuid, :uuid, default: -> { "uuidv7()" }

    # 2. Backfill UUIDs for existing records
    User.find_each do |user|
      user.update_column(:uuid, SecureRandom.uuid)
    end

    # 3. Update foreign keys (complex, requires multiple steps)
    # ... (see online guides for full migration)

    # 4. Swap primary key (requires downtime)
    # ... (extremely risky)
  end
end
```

**Recommendation**: Only use UUIDs for **new tables**. Keep existing tables as-is unless you have a compelling reason to migrate.

## FAQ

### Q: Are UUIDs slower than bigint?

**A**: Not for UUIDv7! Benchmark shows 290s = 290s for 1M row inserts. UUIDv4 is slower (375s) due to random inserts, but UUIDv7's time-ordered structure matches bigint performance.

### Q: What about storage size?

**A**: UUIDs are 16 bytes vs bigint's 8 bytes (2× larger). For most applications, the security benefits outweigh the storage cost. SSDs are cheap; business intelligence leakage is expensive.

### Q: Can I use UUIDs with older PostgreSQL versions?

**A**: This template requires PostgreSQL 18+ for native `uuidv7()`. For older versions:
- PostgreSQL 13+: Use `gen_random_uuid()` (UUIDv4, slower)
- Use ULID gem instead (requires extension)

### Q: Do UUIDs work with ActiveRecord associations?

**A**: Yes, perfectly:

```ruby
class User < ApplicationRecord
  has_many :orders
end

class Order < ApplicationRecord
  belongs_to :user
end

# Works exactly like integer IDs:
user.orders.create(status: 'pending')
```

### Q: Can I still use find_by for UUIDs?

**A**: Yes:

```ruby
Order.find("018f4d9e-5c4a-7000-9f8b-3a4c5d6e7f8a")
Order.find_by(id: "018f4d9e-5c4a-7000-9f8b-3a4c5d6e7f8a")
```

### Q: What if I need shorter URLs?

**A**: Options:
1. Accept 36-character UUIDs (recommended, standard)
2. Remove dashes → 32 characters
3. Use base64 encoding → ~22 characters
4. Use Hashids on top of UUID → configurable length

### Q: Is this overkill for a small project?

**A**: No. The performance is identical to bigint, so there's no downside. Even small projects can benefit from:
- Not revealing user count to competitors
- Avoiding embarrassing "User #3" URLs
- Future-proofing for distributed systems

### Q: When should I use bigint instead?

**A**: Use bigint for:
- Internal-only tables (not exposed via API)
- Join tables (e.g., `orders_products`)
- High-volume logging (millions of rows/day)
- Tables with extreme storage constraints

---

## References

- [RFC 9562: UUIDv7 Specification](https://datatracker.ietf.org/doc/rfc9562/)
- [PostgreSQL 18 UUIDv7 Support](https://www.postgresql.org/about/news/postgresql-18-released-3142/)
- [Performance Benchmark: UUIDv7 vs bigint (2025)](https://dev.to/umangsinha12/postgresql-uuid-performance-benchmarking-random-v4-and-time-based-v7-uuids-n9b)
- [The Nile: UUIDv7 in PostgreSQL 18](https://www.thenile.dev/blog/uuidv7)

---

**Last Updated**: 2025-01-22
**Template Version**: Rails 8 + PostgreSQL 18
