# Faker - Generate fake data for testing and development
# https://github.com/faker-ruby/faker
#
# Generates realistic fake data (names, emails, addresses, phone numbers, etc.)
# Perfect companion for FactoryBot to create realistic test fixtures
#
# Usage examples:
#   Faker::Name.name           # => "John Doe"
#   Faker::Internet.email      # => "john.doe@example.com"
#   Faker::PhoneNumber.phone_number  # => "+1-555-123-4567"
#
# FactoryBot integration:
#   factory :user do
#     name { Faker::Name.name }
#     email { Faker::Internet.email }
#     phone { Faker::PhoneNumber.phone_number }
#   end
#
# No configuration needed - works out of the box
gem "faker", group: [:development, :test]
