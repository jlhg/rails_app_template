# JWT - JSON Web Token
# https://github.com/jwt/ruby-jwt
#
# A pure ruby implementation of RFC 7519 OAuth JSON Web Token (JWT).
# Used for stateless authentication and secure information exchange.
#
# Features:
# - Standard JWT encoding/decoding
# - Multiple signing algorithms (HS256, RS256, etc.)
# - Token expiration and validation
# - Custom claims support
#
# Common use cases:
# - API authentication (access tokens and refresh tokens)
# - Single Sign-On (SSO)
# - Secure data exchange between services
#
# Example:
#   payload = { user_id: 123, exp: Time.now.to_i + 3600 }
#   token = JWT.encode(payload, Rails.application.secret_key_base, "HS256")
#   decoded = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: "HS256" })

gem "jwt"
