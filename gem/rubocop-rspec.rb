# RuboCop RSpec - RSpec-specific RuboCop cops
# https://github.com/rubocop/rubocop-rspec
#
# Code style checking for RSpec test files
#
# Features:
# - 100+ RSpec-specific cops for test quality
# - Test structure and organization best practices
# - Common test antipattern detection
# - RSpec DSL usage enforcement
# - Test readability improvements
#
# Cops Categories:
# - RSpec/DescribeClass: Describe block organization
# - RSpec/ExampleLength: Test case size management
# - RSpec/MultipleExpectations: Assertion count control
# - RSpec/LetSetup: Let vs let! usage
# - RSpec/NestedGroups: Test nesting depth
# - RSpec/ContextWording: Context block naming
#
# Benefits:
# - Enforces RSpec best practices and conventions
# - Improves test readability and maintainability
# - Catches common testing mistakes early
# - Maintains consistent test structure
# - Encourages focused, single-purpose tests
#
# Configuration:
# - Add 'require: rubocop-rspec' to .rubocop.yml
# - Customize RSpec cops in .rubocop.yml
# - Configure based on team preferences
#
# Common Customizations:
# - RSpec/MultipleExpectations: Adjust Max for integration tests
# - RSpec/ExampleLength: Set Max based on test complexity
# - RSpec/NestedGroups: Control describe/context nesting depth
#
# Usage:
#   rubocop spec/ --require rubocop-rspec
#   # Or configure in .rubocop.yml to auto-load
#
# Documentation: https://docs.rubocop.org/rubocop-rspec/

gem "rubocop-rspec", group: :development, require: false
