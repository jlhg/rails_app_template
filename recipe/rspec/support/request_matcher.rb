# frozen_string_literal: true

require "rspec/expectations"

# Custom RSpec matchers for API request specs
# Follows 2025 best practices: provide clear failure messages for faster debugging
# Reference: https://semaphore.io/community/tutorials/how-to-use-custom-rspec-matchers-to-specify-behaviour

# Matcher: Verify response Content-Type is JSON
# Usage: expect(response).to be_json
RSpec::Matchers.define :be_json do
  match do |actual|
    # Support both "application/json" and "application/json; charset=utf-8"
    actual.content_type&.include?("application/json")
  end

  failure_message do |actual|
    "Expected Content-Type to include 'application/json', but got '#{actual.content_type}'"
  end

  failure_message_when_negated do |_actual|
    "Expected Content-Type not to include 'application/json', but it did"
  end

  description do
    "have Content-Type header including 'application/json'"
  end
end

# Matcher: Verify API response contains expected message_code
# Usage: expect(response).to have_message_code(:success)
RSpec::Matchers.define :have_message_code do |expected_key|
  match do |actual|
    @actual_code = actual.parsed_body.dig("result", "message_code")
    @actual_code == expected_key.to_s
  end

  failure_message do |actual|
    "Expected message_code to be '#{expected_key}', but got '#{@actual_code}'\n" \
      "Response body: #{actual.parsed_body}"
  end

  failure_message_when_negated do |_actual|
    "Expected message_code not to be '#{expected_key}', but it was"
  end

  description do
    "have message_code '#{expected_key}' in response body"
  end
end

# Matcher: Verify at least one email was sent
# Usage: expect(mail_deliveries).to have_mail
RSpec::Matchers.define :have_mail do
  match(&:any?)

  failure_message do |actual|
    "Expected to have at least 1 email, but found #{actual.count}"
  end

  failure_message_when_negated do |actual|
    "Expected to have no emails, but found #{actual.count}"
  end

  description do
    "have at least one email delivery"
  end
end

# Matcher: Verify email body contains specific pattern
# Usage: expect(last_email).to have_mail_content(/activation link/)
RSpec::Matchers.define :have_mail_content do |pattern|
  match do |actual|
    @body = actual.body.raw_source
    @body.match?(pattern)
  end

  failure_message do |_actual|
    "Expected email body to match /#{pattern}/, but it didn't.\n" \
      "Actual body (first 500 chars):\n#{@body[0..500]}"
  end

  failure_message_when_negated do |_actual|
    "Expected email body not to match /#{pattern}/, but it did"
  end

  description do
    "have email body matching /#{pattern}/"
  end
end
