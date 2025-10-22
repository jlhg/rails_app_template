# RSpec Request Spec Helpers for API Testing
# Follows 2025 best practices: avoid instance variables, use explicit headers
# Reference: https://www.betterspecs.org/
module RequestHelper
  # Parse JSON response body (DRY up tests)
  # Usage: expect(json_response[:email]).to eq(user.email)
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  # Build authenticated request headers
  # Usage: get '/api/users', headers: auth_headers(user)
  #
  # @param user [User, nil] User object to authenticate (nil for unauthenticated requests)
  # @param additional_headers [Hash] Additional headers to merge
  # @return [Hash] Request headers including Authorization if user provided
  def auth_headers(user = nil, additional_headers = {})
    headers = {
      "Accept"       => "application/json",
      "Content-Type" => "application/json"
    }

    if user
      token = generate_jwt_token(user)
      headers["Authorization"] = "Bearer #{token}"
    end

    headers.merge(additional_headers)
  end

  # Convenience methods for authenticated API requests
  # These methods automatically:
  # - Set proper JSON headers
  # - Add Authorization header if user provided
  # - Encode body as JSON for POST/PATCH
  #
  # Usage:
  #   api_get '/users', user: current_user
  #   api_post '/users', user: admin, params: { name: 'John' }

  def api_get(path, user: nil, params: {}, headers: {})
    get path, params: params, headers: auth_headers(user, headers)
  end

  def api_post(path, user: nil, params: {}, headers: {})
    post path, params: params.to_json, headers: auth_headers(user, headers)
  end

  def api_patch(path, user: nil, params: {}, headers: {})
    patch path, params: params.to_json, headers: auth_headers(user, headers)
  end

  def api_delete(path, user: nil, params: {}, headers: {})
    delete path, params: params, headers: auth_headers(user, headers)
  end

  def api_put(path, user: nil, params: {}, headers: {})
    put path, params: params.to_json, headers: auth_headers(user, headers)
  end

  # Access mail deliveries (clearer naming than 'mailer')
  # Usage: expect(mail_deliveries).to have_mail
  def mail_deliveries
    ActionMailer::Base.deliveries
  end

  # Build params hash from method calls (legacy helper)
  # Usage: request_params(:name, :email) # => { name: user.name, email: user.email }
  def request_params(*keys)
    keys.to_h { |k| [k, send(k)] }
  end

  private

  # Generate JWT token for testing
  # Override this method in your rails_helper.rb if you have custom JWT logic
  #
  # Example override:
  #   module RequestHelper
  #     def generate_jwt_token(user)
  #       JwtService.encode(user_id: user.id)
  #     end
  #   end
  def generate_jwt_token(user)
    JWT.encode(
      { user_id: user.id, exp: 24.hours.from_now.to_i },
      Rails.application.secret_key_base,
      "HS256"
    )
  end
end

RSpec.configure do |config|
  config.include RequestHelper, type: :request

  # Clear mail deliveries before each request spec
  config.before(:each, type: :request) do
    ActionMailer::Base.deliveries.clear
  end
end
