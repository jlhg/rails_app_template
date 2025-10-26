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
# To configure, create config/initializers/rack_attack.rb with your rules.
