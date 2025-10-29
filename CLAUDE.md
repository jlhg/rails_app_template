# Rails Application Template - Development Guide

## ⚠️ Architecture Change (2025-10-30)

**Simplified to Single-Directory Structure**

- **Old**: `gem/` + `recipe/` (two directories, `init_gem` + `recipe`)
- **New**: `recipe/` only (one directory, `recipe` only)
- **Benefit**: Simpler, more intuitive, follows Rails community practices

---

## Project Overview

Rails 8.1 + Ruby 3.4 API template with best practices.

**Key Features:**
- API-only (PostgreSQL 18, Valkey 8)
- UUIDv7 primary keys
- Docker configuration
- Structured logging (Lograge)
- Complete test setup (RSpec, FactoryBot, N+1 detection)
- Security (Rack::Attack, Pundit, JWT, Sentry)

**Usage:**
```bash
rails new <project_name> --api -d postgresql --skip-test -m template/api.rb
```

---

## Project Structure

```
rails_app_template/
├── recipe/                 # Configuration recipes (gem + setup)
│   ├── redis.rb           # Redis/Valkey configuration
│   ├── pagy.rb            # Pagination
│   ├── rspec.rb           # Testing framework
│   ├── sentry.rb          # Error tracking
│   └── config/            # Environment configs
│       ├── cors.rb
│       ├── puma.rb
│       └── log.rb
│
├── template/
│   ├── api.rb             # Main entry point
│   └── files/             # Files to copy
│
└── lib/base.rb            # Helper methods
```

---

## Core Concepts

### Recipe Structure

Each recipe contains **gem installation + configuration**:

```ruby
# recipe/redis.rb
gem "redis"
gem "connection_pool"

initializer "redis.rb", <<~RUBY
  # Redis configuration...
RUBY
```

### Usage in template/api.rb

```ruby
# Simple gems - direct installation
gem "aasm"
gem "alba"

# Complex configuration - use recipes
recipe "redis"
recipe "rspec"
recipe "config/cors"
```

---

## Development Workflow

### Adding a New Feature

1. **Simple gem** (no config needed):
   - Add `gem "xxx"` directly in `template/api.rb`

2. **Complex gem** (needs configuration):
   - Create `recipe/xxx.rb` with gem + config
   - Call `recipe "xxx"` in `template/api.rb`

### Example: Adding Sidekiq

```ruby
# recipe/sidekiq.rb
gem "sidekiq"

initializer "sidekiq.rb", <<~RUBY
  Sidekiq.configure_server do |config|
    config.redis = { url: ENV.fetch('REDIS_URL') }
  end
RUBY
```

```ruby
# template/api.rb
recipe "sidekiq"
```

---

## Testing

```bash
cd /tmp
rails new test_app --api -d postgresql --skip-test \
  -m ~/rails_app_template/template/api.rb

cd test_app
bundle exec rubocop  # Should pass with no offenses
```

---

## Git Conventions

Follow Conventional Commits:

```
feat(recipe): add sidekiq configuration
fix(template): correct gem loading order
refactor(structure): simplify recipe architecture
docs(readme): update installation steps
```

---

## Quick Reference

### Helper Methods (lib/base.rb)

```ruby
recipe(name)              # Load recipe file
eval_file_content(path)   # Execute file content
```

### Rails Template DSL

```ruby
gem "gem_name"                              # Install gem
recipe "recipe_name"                        # Execute recipe
environment "config.x = y"                  # Add to all environments
environment "config.x = y", env: "production"  # Specific environment
initializer "file.rb", "code"               # Create initializer
copy_file "source", "dest"                  # Copy file
route "get '/path', to: 'controller#action'"  # Add route
```

---

**Last Updated:** 2025-10-30
