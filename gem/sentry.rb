# Sentry - Application Monitoring and Error Tracking
# https://github.com/getsentry/sentry-ruby
# https://docs.sentry.io/platforms/ruby/guides/rails/
#
# Industry-standard error tracking and performance monitoring for production Rails applications
# Automatically captures exceptions, performance metrics, and provides detailed debugging context
#
# Key Features:
# - Real-time error tracking with stack traces and context
# - Performance monitoring (APM) for API endpoints, database queries, external requests
# - Release tracking (correlate errors with deployments)
# - Breadcrumbs (action trail leading to errors)
# - Smart alerting and notifications
# - Issue trends and analytics
#
# Benefits:
# - Proactive error detection (know about issues before users report them)
# - Detailed debugging context (request params, user info, environment)
# - Performance bottleneck identification
# - Release health tracking (see if new deployments introduce errors)
# - Integration with issue trackers (Jira, GitHub, etc.)
#
# Example Error Report:
#   NoMethodError: undefined method `name' for nil:NilClass
#   - Stack trace with source code context
#   - Request: POST /api/users
#   - User: user_id=123, ip=1.2.3.4
#   - Environment: production, release=abc123
#   - Breadcrumbs: [login, navigate, click button, error]
#
# Example Performance Insight:
#   /api/users#index
#   - P95 response time: 450ms
#   - Database queries: 8 queries (120ms)
#   - External API calls: 1 call (200ms)
#   - Memory allocation: 15MB
#
# Free Tier:
# - 5,000 errors/month
# - 10,000 performance transactions/month
# - 30-day data retention
# - Perfect for small to medium projects
#
# Configured in recipe/sentry.rb
# - Production environment only (development uses Rails default error pages)
# - 10% performance sampling (configurable via SENTRY_TRACES_SAMPLE_RATE)
# - Automatic sensitive data filtering (passwords, tokens, secrets)
# - Release tracking using git commit SHA
#
# Setup:
# 1. Create account at https://sentry.io
# 2. Create new Rails project
# 3. Copy DSN to SENTRY_DSN environment variable
# 4. Deploy and errors will automatically be reported
gem "sentry-ruby"
gem "sentry-rails"
