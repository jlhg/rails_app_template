# Recipe Development Guide

This guide explains how to develop and maintain recipes for the Rails application template.

## Table of Contents

- [Overview](#overview)
- [Design Principles](#design-principles)
- [Recipe Execution Lifecycle](#recipe-execution-lifecycle)
- [Design Patterns](#design-patterns)
- [Common Scenarios](#common-scenarios)
- [Troubleshooting](#troubleshooting)

## Overview

### What is a Recipe?

A **recipe** is a modular, self-contained unit that configures a specific feature or gem in a Rails application. Recipes should be:

- **Independent**: Can be executed in isolation
- **Reusable**: Can be applied to different projects
- **Complete**: Contains all configuration needed for the feature
- **Clear**: Well-documented and easy to understand

### Directory Structure

```text
rails_app_template/
├── lib/
│   └── base.rb              # Lifecycle hooks and helper methods
├── template/
│   ├── api.rb               # Template entry point (coordinator)
│   └── files/               # Static files and templates
└── recipe/
    ├── pagy.rb              # Pagination recipe
    ├── rspec.rb             # Testing recipe
    ├── sentry.rb            # Error tracking recipe
    └── ...                  # Other recipes
```

## Design Principles

### 1. Separation of Concerns

**Template** (`template/api.rb`):

- Coordinates recipe execution order
- Provides orchestration, not implementation
- Should NOT contain feature-specific logic

**Recipe** (`recipe/*.rb`):

- Contains all configuration for a specific feature
- Includes gem declarations, initializers, generators, and files
- Encapsulates feature logic completely

❌ **Bad Example** (violates separation):

```ruby
# template/api.rb
after_bundle do
  # Directly creating pagy configuration (should be in recipe!)
  initializer "pagy.rb", <<~CODE
    Pagy::OPTIONS[:limit] = 20
  CODE
end
```

✅ **Good Example** (proper separation):

```ruby
# template/api.rb
recipe "pagy"  # Just orchestrate

# recipe/pagy.rb
gem "pagy"
after_generators do
  initializer "pagy.rb", <<~CODE
    Pagy::OPTIONS[:limit] = 20
  CODE
end
```

### 2. Single Responsibility

Each recipe should configure exactly one feature or gem. If a recipe is doing too much, split it into multiple recipes.

### 3. Explicit Dependencies

If a recipe depends on another recipe, document it clearly and ensure execution order in `template/api.rb`.

## Recipe Execution Lifecycle

Understanding the Rails template execution lifecycle is crucial for writing correct recipes.

### Lifecycle Stages

```text
1. Template Execution
   ├── Recipe files are loaded
   ├── Gems are declared with `gem`
   └── Immediate actions execute (create_file, initializer, etc.)

2. after_bundle
   ├── `bundle install` completes
   ├── Gems are installed but not yet fully loaded
   └── Generators can be executed (e.g., `generate "rspec:install"`)

3. Generators Execute
   ├── Rails generators run
   └── May load Rails environment (triggering initializer execution)

4. after_generators
   ├── Custom lifecycle hook (defined in lib/base.rb)
   ├── All generators complete
   ├── Gems are fully available
   └── Safe to create initializers that require gems
```

### Lifecycle Hooks

| Hook | When to Use | Example Use Case |
|------|-------------|------------------|
| Immediate execution | Configuration that doesn't require gems | Setting generator defaults, creating static files |
| `after_bundle` | Running generators, creating config files | RSpec setup, Pundit install |
| `after_generators` | Creating initializers that reference gem constants | Pagy config with `Pagy::OPTIONS` |

## Design Patterns

### Pattern 1: Static Configuration (No Gem Dependencies)

**When to use**: Initializer only configures Rails settings without requiring gems.

**Example**:

```ruby
# recipe/uuidv7.rb
initializer "generators.rb", <<~RUBY
  Rails.application.config.generators do |g|
    g.orm :active_record, primary_key_type: :uuid
  end
RUBY
```

**Characteristics**:

- No `require` statements for gems
- Only uses Rails API
- Can execute immediately

### Pattern 2: Configuration with after_initialize

**When to use**: Initializer needs to access Rails configuration or application objects that are only available after Rails initialization.

**Example**:

```ruby
# recipe/sidekiq.rb
gem "sidekiq", ">= 7.0"

initializer "sidekiq.rb", <<~RUBY
  Rails.application.config.after_initialize do
    redis_config = { url: AppConfig.instance.redis_queue_url }
    Sidekiq.configure_server do |config|
      config.redis = redis_config
    end
  end
RUBY
```

**Characteristics**:

- Uses `Rails.application.config.after_initialize` wrapper
- Can access `AppConfig` and other Rails components
- Safe to use with gem configuration

### Pattern 3: Generator Execution

**When to use**: Recipe needs to run Rails generators.

**Example**:

```ruby
# recipe/rspec.rb
gem "rspec-rails"

after_bundle do
  generate "rspec:install"

  # Additional file operations
  from_files "spec/support"
end
```

**Characteristics**:

- Uses `after_bundle` hook
- Executes generators with `generate` method
- Can perform file operations after generator completes

### Pattern 4: Delayed Initializer Creation

**When to use**: Initializer references constants the gem defines, or requires gem files.

**Example**:

```ruby
# recipe/pagy.rb
gem "pagy", "~> 43.6"

after_generators do
  initializer "pagy.rb", <<~CODE
    Pagy::OPTIONS[:limit] = 20
    Pagy::OPTIONS[:max_limit] = 100

    Pagy::OPTIONS.freeze
  CODE
end
```

**Characteristics**:

- Uses `after_generators` hook (custom lifecycle)
- Ensures generators complete before creating initializer
- Prevents LoadError when generators load Rails environment

### Pattern 5: Hybrid Pattern

**When to use**: Recipe needs both immediate configuration and delayed operations.

**Example**:

```ruby
# recipe/sidekiq.rb
gem "sidekiq", ">= 7.0"

# Immediate: Create configuration file
after_bundle do
  create_file "config/sidekiq.yml", <<~YAML
    :concurrency: 5
    :queues:
      - default
  YAML
end

# Delayed: Create initializer
initializer "sidekiq.rb", <<~RUBY
  Rails.application.config.after_initialize do
    redis_config = { url: AppConfig.instance.redis_queue_url }
    Sidekiq.configure_server { |config| config.redis = redis_config }
  end
RUBY
```

**Characteristics**:

- Combines multiple patterns
- Uses both `after_bundle` and `initializer`
- Separates concerns within the recipe

## Common Scenarios

### Scenario 1: Adding a Simple Gem

```ruby
# recipe/simple_gem.rb
gem "gem_name"

# If no configuration needed, that's it!
# If simple Rails config is needed:
initializer "gem_name.rb", <<~RUBY
  Rails.application.config.gem_setting = true
RUBY
```

### Scenario 2: Adding a Gem with Initializer

```ruby
# recipe/gem_with_config.rb
gem "gem_name"

after_generators do
  initializer "gem_name.rb", <<~CODE
    require "gem_name/feature"
    GemName.configure do |config|
      config.option = value
    end
  CODE
end
```

### Scenario 3: Adding a Gem with Generator

```ruby
# recipe/gem_with_generator.rb
gem "gem_name"

after_bundle do
  generate "gem_name:install"

  # Customize generated files if needed
  inject_into_file "config/generated_file.rb",
    "  custom_config = true\n",
    after: "GemName.configure do |config|\n"
end
```

### Scenario 4: Adding Multiple Related Files

```ruby
# recipe/complex_feature.rb
gem "feature_gem"

after_bundle do
  # Copy directory of files
  from_files "app/services/feature"
  from_files "spec/services/feature"

  # Create individual files
  create_file "config/feature.yml", <<~YAML
    default: &default
      enabled: true

    development:
      <<: *default

    production:
      <<: *default
  YAML
end

after_generators do
  initializer "feature.rb", <<~RUBY
    require "feature_gem"
    FeatureGem.setup do |config|
      config.load_yaml(Rails.root.join("config/feature.yml"))
    end
  RUBY
end
```

## Troubleshooting

### LoadError: cannot load such file

**Symptom**: Generator fails with "cannot load such file -- gem/file"

**Cause**: Initializer tries to `require` a gem before it's fully loaded.

**Solution**: Use `after_generators` hook:

```ruby
# ❌ Wrong
gem "some_gem"
initializer "some_gem.rb", <<~CODE
  require "some_gem/extension"  # LoadError during generators!
CODE

# ✅ Correct
gem "some_gem"
after_generators do
  initializer "some_gem.rb", <<~CODE
    require "some_gem/extension"  # Safe: generators complete, gems loaded
  CODE
end
```

### Configuration Not Available

**Symptom**: Initializer fails with "uninitialized constant AppConfig"

**Cause**: Trying to access Rails components before initialization complete.

**Solution**: Use `after_initialize` wrapper:

```ruby
# ❌ Wrong
initializer "feature.rb", <<~RUBY
  config = AppConfig.instance  # May not be available yet
RUBY

# ✅ Correct
initializer "feature.rb", <<~RUBY
  Rails.application.config.after_initialize do
    config = AppConfig.instance  # Safe: Rails fully initialized
  end
RUBY
```

### Generator Not Found

**Symptom**: Template fails with "Could not find generator 'gem_name:install'"

**Cause**: Generator executed before `bundle install` completes.

**Solution**: Use `after_bundle` hook:

```ruby
# ❌ Wrong
gem "gem_name"
generate "gem_name:install"  # Generator not available yet!

# ✅ Correct
gem "gem_name"
after_bundle do
  generate "gem_name:install"  # Safe: bundle install complete
end
```

## Decision Flowchart

When creating a recipe, follow this decision tree:

```text
Does the recipe need to install a gem?
├─ No
│  └─ Just use immediate execution or create_file
└─ Yes
   └─ Does the initializer require gem files?
      ├─ No
      │  └─ Can use AppConfig or Rails components?
      │     ├─ No → Use direct `initializer`
      │     └─ Yes → Use `initializer` with `after_initialize`
      └─ Yes
         └─ Use `after_generators do; initializer; end`

Does the recipe need to run a generator?
└─ Yes → Use `after_bundle do; generate; end`
```

## Helper Methods Reference

These helper methods are available in recipes (defined in `lib/base.rb`):

### File Operations

- `from_files(path)` - Copy template files to Rails app
- `create_file(path, content)` - Create a file with content
- `inject_into_file(path, content, options)` - Insert content into existing file

### Recipe Management

- `recipe(name)` - Load and execute a recipe file

### Lifecycle Hooks

- `after_generators(&block)` - Register code to run after all generators complete
- `run_after_generators` - Execute all registered after_generators blocks

### Rails Template DSL

Available from Rails template DSL (no need to define):

- `gem(name, *args)` - Declare a gem dependency
- `initializer(name, content)` - Create an initializer file
- `generate(what, *args)` - Run a Rails generator
- `after_bundle(&block)` - Run code after bundle install

## Examples from Existing Recipes

### Pattern 1: Static Configuration

- `recipe/uuidv7.rb` - Generator settings
- `recipe/i18n.rb` - I18n configuration

### Pattern 2: Configuration with after_initialize

- `recipe/sidekiq.rb` - Sidekiq setup with AppConfig
- `recipe/redis.rb` - Redis configuration
- `recipe/sentry.rb` - Sentry error tracking

### Pattern 3: Generator Execution

- `recipe/rspec.rb` - RSpec installation
- `recipe/pundit.rb` - Pundit authorization
- `recipe/action_storage.rb` - Active Storage setup

### Pattern 4: Delayed Initializer

- `recipe/pagy.rb` - Pagination with gem requires

### Pattern 5: Hybrid

- `recipe/sidekiq.rb` - Config file + initializer

## Best Practices

1. **Keep recipes focused**: One feature per recipe
2. **Use appropriate hooks**: Follow the decision flowchart
3. **Document dependencies**: If recipe A needs recipe B, document it
4. **Test thoroughly**: Create a new Rails app and verify the template works
5. **Handle errors gracefully**: Provide clear error messages
6. **Follow existing patterns**: Look at similar recipes for guidance
7. **Update this guide**: When you discover a new pattern, document it

## Testing Recipes

### Manual Testing

```bash
# Create a test Rails application
cd /tmp
rails new test_app --api -d postgresql --skip-test --skip-solid \
  -m /path/to/rails_app_template/template/api.rb

# Verify the generated application
cd test_app
cat config/initializers/pagy.rb  # Check initializers
bundle exec rspec --version      # Verify gems work
docker compose up -d             # Test Docker setup
```

### Automated Testing

Create a test script (see `tmp/test_template.sh`) to verify:

- Template executes without errors
- All initializers are created
- Generators complete successfully
- No LoadError or other exceptions

## Contributing

When adding or modifying recipes:

1. Follow the design patterns in this guide
2. Test your changes thoroughly
3. Update this guide if you introduce new patterns
4. Run RuboCop to ensure code quality
5. Document any new helper methods or hooks

## References

- Main template: `template/api.rb`
- Helper methods: `lib/base.rb`
- Recipe directory: `recipe/`
- Rails template guide: <https://guides.rubyonrails.org/rails_application_templates.html>
