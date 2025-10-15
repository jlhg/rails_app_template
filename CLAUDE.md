# Rails Application Template - Development Guide

## Project Overview

This is a **Rails 8 application template project** for quickly creating Rails API projects following best practices.

**Key Features:**
- ✅ Rails 8 + Ruby 3.4 optimizations (YJIT enabled)
- ✅ API-only architecture (PostgreSQL 18, Valkey 8)
- ✅ Production-grade Docker configuration (multi-stage build, secrets management)
- ✅ Structured logging (Lograge)
- ✅ Complete test configuration (RSpec, FactoryBot, N+1 detection)
- ✅ Security best practices (Rack::Attack, Pundit, JWT)

**Usage:**
```bash
rails new <project_name> --api -d postgresql --skip-test -m template/api.rb
```

## Project Structure

```
rails_app_template/
├── gem/                    # Gem installation scripts (one file per gem)
│   ├── alba.rb            # JSON serializer
│   ├── lograge.rb         # Structured logging
│   ├── pagy.rb            # Pagination
│   ├── rack-attack.rb     # API rate limiting
│   └── ...                # Other gems
│
├── recipe/                 # Configuration recipes (modular configuration)
│   ├── config.rb          # Main configuration coordinator
│   ├── rspec.rb           # RSpec testing framework setup
│   ├── action_storage.rb  # ActiveStorage configuration
│   ├── action_cable.rb    # ActionCable configuration
│   ├── database_yml.rb    # database.yml generator
│   ├── config/            # Environment configuration subdirectory
│   │   ├── log.rb         # Logging configuration (Lograge)
│   │   ├── pg.rb          # PostgreSQL configuration
│   │   ├── puma.rb        # Puma server configuration
│   │   ├── cors.rb        # CORS settings
│   │   └── ...
│   └── rspec/support/     # RSpec support files
│       ├── bcrypt.rb      # BCrypt test optimization
│       ├── mock_redis.rb  # Redis mock setup
│       ├── prosopite.rb   # N+1 query detection
│       └── ...
│
├── template/               # Rails template main files
│   ├── api.rb             # Main template entry point (rails new -m points here)
│   └── files/             # Files to copy to new project
│       ├── Dockerfile
│       ├── compose.yaml
│       ├── .env.example
│       ├── .secrets/      # Docker secrets examples
│       ├── docs/          # Project documentation templates
│       └── ...
│
├── lib/                    # Helper methods
│   └── base.rb            # Helper methods: init_gem, recipe, environment, etc.
│
├── README.md               # User documentation (user perspective)
├── CLAUDE.md               # Development guide (developer perspective)
└── .rubocop.yml            # RuboCop configuration
```

## Core Concepts

### 1. Helper Methods (lib/base.rb)

```ruby
# Install and load gem (from gem/ directory)
init_gem "pagy"
# → Executes content of gem/pagy.rb

# Execute recipe (from recipe/ directory)
recipe "config"
# → Executes content of recipe/config.rb

# Add environment configuration
environment "config.log_level = :debug", env: "development"
# → Adds to config/environments/development.rb
```

### 2. Gem Installation Flow

**Purpose of gem/ directory:**
- Each file corresponds to one gem
- Contains gem installation command and descriptive comments
- Loaded using `init_gem` method

**Example: gem/lograge.rb**
```ruby
# Lograge - Tame Rails' Default Logging
# https://github.com/roidrage/lograge
#
# [Detailed description...]
#
# Configured in recipe/config/log.rb for production environment only
gem "lograge"
```

### 3. Recipe Execution Flow

**Purpose of recipe/ directory:**
- Modular configuration scripts
- Handle complex configuration logic
- Can nest calls to other recipes

**Example: recipe/config.rb**
```ruby
# First initialize required gems
init_gem "config"
init_gem "rack-cors"
init_gem "lograge"

# Then execute related configuration recipes
recipe "config/time_zone"
recipe "config/cors"
recipe "config/log"
```

**Important Rules:**
1. Must `init_gem` before using that gem
2. Don't `init_gem` inside recipe (causes gem not found)
3. All `init_gem` should be centralized in main coordinator (template/api.rb or recipe/config.rb)

## Development Workflow

### 1. Adding a Gem

**Steps:**
1. Create `gem/<gem_name>.rb`
2. Call `init_gem "<gem_name>"` in main file
3. If configuration needed, create corresponding recipe

**Example: Adding sidekiq**

```bash
# 1. Create gem/sidekiq.rb
cat > gem/sidekiq.rb << 'EOF'
# Sidekiq - Background Job Processing
# https://github.com/sidekiq/sidekiq
#
# Simple, efficient background processing for Ruby
# Uses Redis for job queue management
#
# Benefits:
# - High performance (processes thousands of jobs/second)
# - Web UI for monitoring
# - Reliable job retry mechanism
# - Low memory footprint
#
# Configured in config/initializers/sidekiq.rb
gem "sidekiq"
EOF

# 2. Add to template/api.rb
# init_gem "sidekiq"

# 3. Create configuration recipe (optional)
cat > recipe/sidekiq.rb << 'EOF'
# Sidekiq configuration
initializer "sidekiq.rb", <<~RUBY
  Sidekiq.configure_server do |config|
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
  end

  Sidekiq.configure_client do |config|
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
  end
RUBY
EOF
```

### 2. Adding a Recipe

**Steps:**
1. Create `recipe/<feature_name>.rb`
2. Use Rails template DSL (copy_file, initializer, environment, etc.)
3. Call `recipe "<feature_name>"` in main file

**Example: Adding GraphQL configuration**

```bash
cat > recipe/graphql.rb << 'EOF'
# GraphQL API configuration

# Install GraphQL gem
gem "graphql"

# Generate GraphQL files
generate "graphql:install"

# Add GraphQL route
route 'post "/graphql", to: "graphql#execute"'

# Update CORS to allow GraphQL introspection
inject_into_file "config/initializers/cors.rb",
  after: "origins '*'\n" do
  <<~RUBY
    # Allow GraphQL introspection headers
    allow do
      origins '*'
      resource '/graphql',
        headers: :any,
        methods: [:post, :options]
    end
  RUBY
end
EOF
```

### 3. Modifying Existing Configuration

**Principles:**
- Prefer modifying recipe files (don't directly edit template/api.rb)
- Maintain modularity (one recipe handles one feature area)
- Add comments explaining modification reasons

**Example: Modifying Redis configuration**

```bash
# Modify recipe/config/redis.rb (if exists)
# Or modify comments in gem/redis.rb
```

### 4. Testing Template

**Full test:**
```bash
# Create test project
cd /tmp
rails new test_app --api -d postgresql --skip-test \
  -m /home/jlhg/work/jlhg/rails_app_template/template/api.rb

# Check for errors
cd test_app
bundle install  # Should have no errors
```

**Quick validation:**
```bash
# If only modifying specific gem/recipe, test that part alone
cd /tmp
rails new quick_test --api -d postgresql --skip-test -m - << 'EOF'
require "/home/jlhg/work/jlhg/rails_app_template/lib/base.rb"
init_gem "lograge"
recipe "config/log"
EOF
```

**Checklist:**
- ✅ No gem duplication warnings
- ✅ No gem not found errors
- ✅ bundle install succeeds
- ✅ Generated files correct (check config/, spec/, Dockerfile, etc.)
- ✅ RuboCop passes (if .rubocop.yml modified)

## Common Tasks

### Task 1: Add Default Installed Gem

**Location:** `template/api.rb`

```ruby
# Add to template/api.rb
init_gem "devise"        # Add this line
init_gem "aasm"
init_gem "pagy"
# ...
```

### Task 2: Remove Unnecessary Gem

**Steps:**
1. Remove `init_gem` line from `template/api.rb`
2. Delete or keep `gem/<gem_name>.rb` (keep for optional use)
3. Remove related recipe calls

### Task 3: Update Rails 8 Compatibility

**Check items:**
1. Verify Rails 8 default included gems (avoid duplication)
   - `debug` gem (Ruby 3.1+)
   - Health check endpoint (`/up`)
   - Solid Queue, Solid Cache (Rails 8 additions)

2. Check deprecated configuration
   ```bash
   # Create Rails 8 test project
   rails new rails8_test --api -d postgresql --skip-test --skip-bundle

   # Compare default configuration
   diff rails8_test/config/environments/production.rb \
        test_app/config/environments/production.rb
   ```

### Task 4: Update Documentation

**Files that need synchronization:**
- `README.md` - User documentation
- `gem/<gem_name>.rb` - Gem description comments
- `recipe/*.rb` - Recipe header comments
- `template/files/docs/*.md` - Project documentation templates (if relevant)

## Considerations and Common Pitfalls

### ⚠️ 1. Gem Loading Order

**Wrong: init_gem inside recipe**
```ruby
# ❌ recipe/config/log.rb (wrong)
init_gem "lograge"  # Will error: gem not found

environment "config.lograge.enabled = true", env: "production"
```

**Correct: init_gem in main coordinator**
```ruby
# ✅ recipe/config.rb (correct)
init_gem "lograge"  # Initialize here

recipe "config/log"  # Then execute configuration
```

**Reason:** `init_gem` executes `gem "..."` command, must complete before `bundle install`. Recipe executes when gem may not yet be installed.

### ⚠️ 2. Rails 8 Default Gems

**Checklist:**
- ✅ `debug` gem - Rails 8 includes by default, don't install duplicate
- ✅ `config.silence_healthcheck_path = "/up"` - Rails 8 default config, don't duplicate
- ✅ Solid Queue, Solid Cache - Rails 8 additions, evaluate if needed

**Verification:**
```bash
# Create clean Rails 8 project
rails new rails8_check --api -d postgresql --skip-test --skip-bundle

# Check Gemfile
grep "gem 'debug'" rails8_check/Gemfile

# Check production.rb
grep "silence_healthcheck_path" rails8_check/config/environments/production.rb
```

### ⚠️ 3. Duplicate Gem Installation

**Problem:** Multiple recipes call same `init_gem`

**Solution:**
- Centrally manage all `init_gem` in main coordinator
- When different recipes share same gem, call once in coordinator only

**Example:**
```ruby
# ✅ recipe/config.rb (coordinator)
init_gem "rack-cors"  # Initialize only once here

recipe "config/cors"
recipe "action_storage"  # This recipe also needs rack-cors, but don't repeat init_gem
```

### ⚠️ 4. Environment Configuration Location

**Rules:**
- **Production environment config** → `environment "...", env: "production"`
- **Development environment config** → `environment "...", env: "development"`
- **Test environment config** → `environment "...", env: "test"`
- **All environments** → `environment "..."` (no env parameter)

**Example:**
```ruby
# ✅ Correct: Lograge only enabled in production
environment <<~RUBY, env: "production"
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
RUBY

# ✅ Correct: Settings needed in all environments
environment <<~RUBY
  config.time_zone = ENV.fetch('TIME_ZONE', 'Asia/Taipei')
RUBY
```

### ⚠️ 5. Documentation Synchronization

**Rule:** When modifying features, must synchronize related documentation

**Checklist:**
1. README.md "Included Gems" section
2. gem/<gem_name>.rb comment descriptions
3. template/files/docs/ related documentation
4. CLAUDE.md (this file) if development conventions changed

### ⚠️ 6. Secrets and Sensitive Data

**Never:**
- ❌ Use real passwords in example files
- ❌ Include real API keys in documentation
- ❌ Commit `.env` or `.secrets/*` (non-.example files)

**Correct approach:**
- ✅ Use `.example` suffix (will be copied but doesn't contain real values)
- ✅ Documentation examples use `YOUR_TOKEN_HERE` etc. placeholders
- ✅ `.gitignore` includes all sensitive file patterns

## Git Commit Conventions

**Commit message format:** Follow Conventional Commits

```
<type>(<scope>): <subject>

<body>
```

**Type definitions:**
- `feat`: New feature (new gem, new recipe)
- `fix`: Bug fix (gem loading, configuration)
- `refactor`: Refactoring (improve recipe structure)
- `docs`: Documentation update (README, gem comments)
- `chore`: Miscellaneous (RuboCop config, .gitignore)

**Examples:**
```bash
# Add gem
feat(gem): Add sidekiq for background job processing

# Fix loading order
fix(template): Move lograge initialization to recipe/config.rb

Fixes gem not found error by initializing lograge before
configuration recipes are executed.

# Update documentation
docs(readme): Update lograge configuration section

# Remove duplicate configuration
fix(config): Remove duplicate silence_healthcheck_path

Rails 8 includes this configuration by default in production.rb
```

## Testing Strategy

### 1. Full Test (Before Each Release)

```bash
# Create full test project
cd /tmp
rails new full_test --api -d postgresql --skip-test \
  -m /home/jlhg/work/jlhg/rails_app_template/template/api.rb

# Verify
cd full_test
bundle install
bundle exec rails db:create db:migrate
bundle exec rails runner 'puts "Rails app is ready!"'
```

### 2. Quick Validation (During Development)

```bash
# Test only specific modifications
cd /tmp
rails new quick_test --api -d postgresql --skip-test -m - << 'EOF'
require "/home/jlhg/work/jlhg/rails_app_template/lib/base.rb"

# Test your modifications
init_gem "your_gem"
recipe "your_recipe"
EOF
```

### 3. Check Items

**Automated checks:**
- ✅ No Bundler warnings (gem duplication, version conflicts)
- ✅ No Rails errors (initializer, environment)
- ✅ RuboCop passes (if .rubocop.yml modified)

**Manual checks:**
- ✅ Files generated correctly (Dockerfile, compose.yaml, .env.example)
- ✅ Configuration file content correct (config/environments/, config/initializers/)
- ✅ Documentation synchronized (README.md, gem comments)

## Advanced Topics

### 1. Conditional Installation

If you need to decide whether to install a gem based on parameters:

```ruby
# template/api.rb
ARGS = ARGV.join(" ").scan(/--?([^=\s]+)\s*(?:=?([^\s-]+))?/).to_h

# Conditional installation
if ARGS['sidekiq'] == 'true'
  init_gem "sidekiq"
  recipe "sidekiq"
end
```

Usage:
```bash
rails new myapp --api -d postgresql --skip-test \
  -m template/api.rb -- --sidekiq=true
```

### 2. Custom Configuration

Users can pass custom configuration via parameters:

```ruby
# template/api.rb
database_name = ARGS['db_name'] || 'myapp'
app_name = ARGS['app_name'] || File.basename(destination_root)

# Use custom configuration
initializer "custom_config.rb", <<~RUBY
  Rails.application.config.x.app_name = "#{app_name}"
  Rails.application.config.x.database_name = "#{database_name}"
RUBY
```

### 3. Version Compatibility Check

Ensure Rails and Ruby versions meet requirements:

```ruby
# template/api.rb (at beginning)
ruby_version = Gem::Version.new(RUBY_VERSION)
rails_version = Gem::Version.new(Rails::VERSION::STRING)

if ruby_version < Gem::Version.new('3.4.0')
  puts "Warning: This template is optimized for Ruby 3.4+"
end

if rails_version < Gem::Version.new('8.0.0')
  puts "Warning: This template is optimized for Rails 8+"
end
```

## Reference Resources

**Official documentation:**
- [Rails Application Templates](https://guides.rubyonrails.org/rails_application_templates.html)
- [Rails Generators](https://guides.rubyonrails.org/generators.html)

**Project documentation:**
- README.md - User guide
- template/files/docs/ - Generated project documentation templates
  - AUTHENTICATION.md - Authentication architecture guide
  - RATE_LIMITING.md - API rate limiting guide
  - ZERO_DOWNTIME_DEPLOYMENT.md - Zero-downtime deployment
  - REDIS_ARCHITECTURE.md - Redis/Valkey architecture

## Quick Reference

### Common Commands

```bash
# Create test project
cd /tmp && rails new test_app --api -d postgresql --skip-test \
  -m ~/work/jlhg/rails_app_template/template/api.rb

# Check Rails 8 default configuration
rails new rails8_default --api -d postgresql --skip-test --skip-bundle
grep -r "config\." rails8_default/config/environments/

# Run RuboCop
cd ~/work/jlhg/rails_app_template
rubocop

# Test specific recipe
cd /tmp && rails new test_recipe --api -d postgresql --skip-test -m - << 'EOF'
require "~/work/jlhg/rails_app_template/lib/base.rb"
recipe "your_recipe"
EOF
```

### File Path Rules

```
gem/<gem_name>.rb          → Install gem + description comments
recipe/<feature>.rb        → Feature configuration script
recipe/<domain>/*.rb       → Domain-related configuration (config/, rspec/support/)
template/api.rb            → Main template entry point
template/files/*           → Files to copy (Dockerfile, .env.example)
lib/base.rb                → Helper methods (don't modify)
```

### Helper Methods Quick Reference

```ruby
init_gem "gem_name"                              # Load gem/gem_name.rb
recipe "recipe_name"                             # Load recipe/recipe_name.rb
environment "config.x = y"                       # Add to all environments
environment "config.x = y", env: "production"    # Add to production.rb
initializer "file.rb", "code"                    # Create config/initializers/file.rb
copy_file "source", "dest"                       # Copy file
directory "source_dir", "dest_dir"               # Copy directory
inject_into_file "path", after: "text" do        # Insert content into file
route "get '/api/status', to: 'status#show'"     # Add route
```

---

**Last Updated:** 2025-10-15
**Maintainer:** jlhg
**Project Version:** Rails 8 + Ruby 3.4
