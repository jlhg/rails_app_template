# Rails 4.1+ has built-in time helpers via ActiveSupport::Testing::TimeHelpers
# No need for timecop gem
# Reference: https://api.rubyonrails.org/classes/ActiveSupport/Testing/TimeHelpers.html

RSpec.configure do |config|
  # Include Rails' built-in time helpers (travel_to, freeze_time, etc.)
  config.include ActiveSupport::Testing::TimeHelpers

  # Freeze time to a specific timestamp for all tests
  # This ensures consistent time-dependent test results
  config.before(:suite) do
    freeze_time Time.parse("2017-09-13T17:10:06.445+08:00")
  end

  # Unfreeze time after all tests complete
  config.after(:suite) do
    unfreeze_time
  end

  # Ensure time is unfrozen after each test to prevent leakage
  config.after(:each) do
    travel_back
  end
end

# Migration guide from Timecop to Rails TimeHelpers:
#
# Timecop.freeze(time) { ... }    → freeze_time(time) { ... }
# Timecop.travel(time) { ... }    → travel_to(time) { ... }
# Timecop.return                  → travel_back or unfreeze_time
# Timecop.scale(scalar) { ... }   → (not available in TimeHelpers)
