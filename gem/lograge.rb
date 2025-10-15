# Lograge - Tame Rails' Default Logging
# https://github.com/roidrage/lograge
#
# Transforms Rails' verbose multi-line logs into concise, structured single-line logs
# Perfect for production environments where you need clean, machine-readable output
#
# Before (Rails default):
#   Started GET "/api/users" for 172.18.0.1 at 2025-01-15 10:00:00 +0000
#   Processing by Api::UsersController#index as JSON
#   User Load (1.2ms)  SELECT "users".* FROM "users"
#   Completed 200 OK in 45ms (Views: 12.3ms | ActiveRecord: 23.4ms | Allocations: 15678)
#
# After (Lograge JSON):
#   {"method":"GET","path":"/api/users","format":"json","controller":"Api::UsersController","action":"index","status":200,"duration":45.67,"view":12.34,"db":23.45,"request_id":"abc123"}
#
# Benefits:
# - Reduces log volume (4+ lines → 1 line)
# - JSON format for easy parsing (ELK, Datadog, CloudWatch)
# - Better performance than default Rails logger
# - Essential for production monitoring and debugging
#
# Configured in recipe/config/log.rb for production environment only
# Development keeps human-readable format
gem "lograge"
