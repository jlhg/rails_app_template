# ActiveStorage testing configuration
# Sets up default host for URL generation and cleans up test files
RSpec.configure do |config|
  config.before do
    # Set default host for URL generation in tests
    # This is used by Rails routing helpers (e.g., user_url(user))
    Rails.application.routes.default_url_options[:host] = "test.example.org"

    # Mock ActiveStorage host for generating URLs
    # This prevents ActiveStorage from trying to access actual host
    allow(ActiveStorage::Current).to receive(:host).and_return("test.example.org")
  end

  # Clean up ActiveStorage test files after all tests complete
  # Prevents test storage directory from accumulating files
  config.after(:suite) do
    FileUtils.rm_rf(Rails.root.join("tmp/storage"))
  end
end
