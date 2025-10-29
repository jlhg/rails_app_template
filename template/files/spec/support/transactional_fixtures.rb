# Rails 5.1+ has built-in support for transactional tests
# No need for database_cleaner gem in most cases
#
# For system tests with JavaScript (using Selenium), Rails handles
# database transactions properly via shared connections.
#
# Reference: https://guides.rubyonrails.org/testing.html#testing-parallel-transactions

RSpec.configure do |config|
  # Use transactional tests for all specs
  # This is the default Rails behavior and works well for:
  # - Model specs
  # - Request specs
  # - System specs (Rails 5.1+)
  #
  # Note: In RSpec Rails 6.1+, use_transactional_fixtures was renamed to use_transactional_tests
  # For compatibility, we set both (only one will be used depending on RSpec version)
  config.use_transactional_tests = true if config.respond_to?(:use_transactional_tests=)
  config.use_transactional_fixtures = true if config.respond_to?(:use_transactional_fixtures=)

  # For system tests with JavaScript drivers (if needed in the future)
  # Rails 5.1+ automatically handles database sharing between threads
  # No additional configuration needed unless using very old Rails versions

  # Load seeds before test suite runs
  # This ensures test data from db/seeds.rb is available for all specs
  config.before(:suite) do
    Rails.application.load_seed if Rails.env.test?

    # Add custom seed logic for test cases below this line
    # Example:
    #   FactoryBot.create(:admin_user, email: 'admin@test.org')
  end
end
