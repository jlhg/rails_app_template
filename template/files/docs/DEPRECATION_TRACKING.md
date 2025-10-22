# Deprecation Warning Tracking

This Rails application template includes automatic deprecation warning detection during RSpec tests.

## Overview

The deprecation tracking system helps you identify and fix deprecated code before upgrading Ruby or Rails versions. It captures warnings from:

- **Ruby deprecations**: Deprecated syntax, methods, or features
- **Rails deprecations**: ActiveSupport::Deprecation warnings
- **Gem deprecations**: Third-party library warnings

## How It Works

The system is automatically configured when you create a project using this template. It includes:

1. **`spec/support/deprecation_tracking.rb`** - Captures all deprecation warnings during test execution
2. **`.rspec`** - Configured with `--warnings` flag to enable Ruby warnings
3. **Automatic reporting** - Displays a formatted report after all specs complete

## Usage

### Basic Usage

Simply run your specs normally:

```bash
bundle exec rspec
```

If any deprecation warnings are detected, you'll see a detailed report after all tests complete:

```
================================================================================
DEPRECATION WARNINGS DETECTED (3)
================================================================================

1. method_name is deprecated and will be removed in Rails 8.1
   Occurrences: 2
   First location: app/models/user.rb:42
   Other locations:
     - app/services/user_service.rb:15

2. Using legacy syntax for validates
   Occurrences: 1
   First location: app/models/order.rb:10

================================================================================
SUMMARY: 3 deprecation warning(s) found
================================================================================
```

### Environment Variables

#### FAIL_ON_DEPRECATIONS

Fail the test suite if any deprecation warnings are found:

```bash
FAIL_ON_DEPRECATIONS=true bundle exec rspec
```

This is useful for CI/CD pipelines to prevent merging code with deprecations:

```yaml
# .github/workflows/ci.yml
- name: Run tests with deprecation enforcement
  run: FAIL_ON_DEPRECATIONS=true bundle exec rspec
  env:
    RAILS_ENV: test
```

#### DEPRECATION_WARNINGS_FILE

Save deprecation warnings to a file for later analysis:

```bash
DEPRECATION_WARNINGS_FILE=tmp/deprecations.txt bundle exec rspec
```

This creates a detailed report file:

```
Deprecation Warnings Report
Generated: 2025-10-22 10:59:38 +0800
Total: 3

1. method_name is deprecated and will be removed in Rails 8.1
   Occurrences: 2
   Locations:
     - app/models/user.rb:42
     - app/services/user_service.rb:15

2. Using legacy syntax for validates
   Occurrences: 1
   Locations:
     - app/models/order.rb:10
```

### Disable Warnings Temporarily

If you need to run specs without deprecation warnings (e.g., for faster feedback during development):

```bash
bundle exec rspec --no-warnings
```

## Common Deprecation Fixes

### Ruby Deprecations

#### 1. Deprecated keyword argument syntax (Ruby 2.7+)

**Warning:**
```
warning: Using the last argument as keyword parameters is deprecated
```

**Fix:**
```ruby
# Before (deprecated)
def create_user(name, email, options)
  User.create(name: name, email: email, **options)
end
create_user("John", "john@example.com", { admin: true })

# After (correct)
def create_user(name, email, **options)
  User.create(name: name, email: email, **options)
end
create_user("John", "john@example.com", admin: true)
```

#### 2. URI.escape/URI.encode (Ruby 3.0+)

**Warning:**
```
warning: URI.escape is deprecated
```

**Fix:**
```ruby
# Before (deprecated)
URI.escape("hello world")

# After (correct)
CGI.escape("hello world")
# or
ERB::Util.url_encode("hello world")
```

### Rails Deprecations

#### 1. ActiveRecord where.not with multiple attributes

**Warning:**
```
DEPRECATION WARNING: Passing a hash with more than one element to where.not is deprecated
```

**Fix:**
```ruby
# Before (deprecated)
User.where.not(role: 'admin', status: 'inactive')

# After (correct)
User.where.not(role: 'admin').where.not(status: 'inactive')
# or using Arel
User.where(User.arel_table[:role].not_eq('admin').and(User.arel_table[:status].not_eq('inactive')))
```

#### 2. update_attributes (Rails 6.0+)

**Warning:**
```
DEPRECATION WARNING: update_attributes is deprecated and will be removed from Rails
```

**Fix:**
```ruby
# Before (deprecated)
user.update_attributes(name: "John")

# After (correct)
user.update(name: "John")
```

#### 3. returning false in callbacks (Rails 5.0+)

**Warning:**
```
DEPRECATION WARNING: Returning false in Active Record callbacks will not implicitly halt a callback chain
```

**Fix:**
```ruby
# Before (deprecated)
before_save :check_status
def check_status
  return false if status_invalid?
  true
end

# After (correct)
before_save :check_status
def check_status
  throw(:abort) if status_invalid?
end
```

## CI/CD Integration

### GitHub Actions

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Run tests with deprecation enforcement
        run: |
          FAIL_ON_DEPRECATIONS=true \
          DEPRECATION_WARNINGS_FILE=tmp/deprecations.txt \
          bundle exec rspec

      - name: Upload deprecation report
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: deprecation-warnings
          path: tmp/deprecations.txt
```

### GitLab CI

```yaml
test:
  script:
    - bundle install
    - |
      FAIL_ON_DEPRECATIONS=true \
      DEPRECATION_WARNINGS_FILE=deprecations.txt \
      bundle exec rspec
  artifacts:
    when: on_failure
    paths:
      - deprecations.txt
    expire_in: 1 week
```

## Upgrading Strategy

When preparing for a Ruby or Rails upgrade:

1. **Run tests locally** to identify all deprecation warnings:
   ```bash
   DEPRECATION_WARNINGS_FILE=deprecations.txt bundle exec rspec
   ```

2. **Review the report** and prioritize fixes based on:
   - Frequency of occurrence
   - Impact on critical paths
   - Complexity of the fix

3. **Fix deprecations incrementally**:
   - Create separate PRs for each type of deprecation
   - Add tests to ensure fixes don't break functionality
   - Update dependencies if needed

4. **Enable CI enforcement** once all deprecations are fixed:
   ```yaml
   # .github/workflows/ci.yml
   env:
     FAIL_ON_DEPRECATIONS: true
   ```

5. **Perform the upgrade** with confidence knowing your codebase is clean

## Troubleshooting

### False Positives

Some gems may emit warnings that aren't true deprecations. To filter these:

```ruby
# spec/support/deprecation_tracking.rb
# Add to the Warning.warn override:

def warn(message)
  # Skip known false positives
  return super if message.include?("gem_name")

  if message.include?("deprecated") || message.include?("deprecation")
    # ... existing code
  end
  super
end
```

### No Warnings Detected

If you expect warnings but none are shown:

1. **Check `.rspec` configuration** - Ensure `--warnings` is enabled
2. **Verify support file is loaded** - Check `spec/support/deprecation_tracking.rb` exists
3. **Run with explicit flag**:
   ```bash
   RUBYOPT="-W:deprecated" bundle exec rspec
   ```

## Resources

- [Ruby Deprecation Warnings](https://docs.ruby-lang.org/en/master/Warning.html)
- [Rails Upgrade Guides](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
- [ActiveSupport::Deprecation](https://api.rubyonrails.org/classes/ActiveSupport/Deprecation.html)

## See Also

- [ZERO_DOWNTIME_DEPLOYMENT.md](ZERO_DOWNTIME_DEPLOYMENT.md) - Deployment strategies
- [TESTING.md](../README.md#testing) - Testing guidelines
