require "prosopite"

# Prosopite N+1 query detection for RSpec tests
# Automatically detects N+1 queries in all request specs with zero false positives

RSpec.configure do |config|
  config.before(:suite) do
    # Configure Prosopite for test environment
    Prosopite.rails_logger = true
    Prosopite.enabled = true
    Prosopite.raise = true # Fail tests immediately when N+1 is detected
  end

  # Wrap each request spec with Prosopite detection
  config.around(:each, type: :request) do |example|
    Prosopite.scan
    example.run
  ensure
    Prosopite.finish
  end
end
