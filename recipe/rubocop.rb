# RuboCop - Ruby Code Style Checker
# https://github.com/rubocop/rubocop
#
# RuboCop is a Ruby static code analyzer and formatter based on the
# community Ruby style guide.
#
# Features:
# - Automatic code style enforcement
# - Auto-correction for many violations
# - Customizable rules via .rubocop.yml
# - Integration with CI/CD pipelines
#
# Extensions:
# - rubocop-rails: Rails-specific cops
# - rubocop-rspec: RSpec-specific cops
#
# Usage:
#   bundle exec rubocop                  # Check all files
#   bundle exec rubocop -A               # Auto-correct violations
#   bundle exec rubocop app/models       # Check specific directory
#
# Note: .rubocop.yml configuration is provided by this template

gem "rubocop"
gem "rubocop-rails"
gem "rubocop-rspec"
