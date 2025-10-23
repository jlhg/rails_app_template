# RuboCop Rails - Rails-specific RuboCop cops
# https://github.com/rubocop/rubocop-rails
#
# Automatic Rails code style checking tool with RuboCop
#
# Features:
# - 90+ Rails-specific cops for best practices
# - ActiveRecord optimization and N+1 detection
# - Migration safety checks
# - Security vulnerability detection (SQL injection, XSS, etc.)
# - Rails idiom enforcement
# - Performance optimization suggestions
#
# Cops Categories:
# - Rails/ActiveRecord: ActiveRecord best practices
# - Rails/Migration: Database migration safety
# - Rails/Security: Security vulnerability detection
# - Rails/Performance: Performance optimization
# - Rails/Validation: Model validation best practices
#
# Benefits:
# - Enforces Rails conventions and best practices
# - Catches common Rails antipatterns early
# - Improves code security and performance
# - Maintains consistency across Rails codebase
#
# Configuration:
# - Add 'require: rubocop-rails' to .rubocop.yml
# - Specify TargetRailsVersion in .rubocop.yml
# - Customize cops in .rubocop.yml as needed
#
# Usage:
#   rubocop --require rubocop-rails
#   # Or configure in .rubocop.yml to auto-load
#
# Documentation: https://docs.rubocop.org/rubocop-rails/

gem "rubocop-rails", group: :development, require: false
