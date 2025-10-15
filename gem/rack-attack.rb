# Rack middleware for blocking & throttling abusive requests.
# https://github.com/rack/rack-attack
gem "rack-attack"

# NOTE: No default rate limiting configuration provided.
# Each application has different rate limiting needs based on:
# - Traffic patterns (public vs private API)
# - User types (anonymous vs authenticated)
# - Endpoint sensitivity (login vs read-only)
# - Business requirements (subscription tiers)
#
# See docs/RATE_LIMITING.md for:
# - Best practices and strategies
# - Complete examples for different scenarios
# - Testing and monitoring guidance
#
# To configure, create config/initializers/rack_attack.rb with your rules.
