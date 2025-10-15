# Rails N+1 queries auto-detection with zero false positives / false negatives
# https://github.com/charkost/prosopite
#
# Prosopite monitors all SQL queries using Active Support instrumentation and
# looks for patterns present in all N+1 query cases: more than one query with
# the same call stack and query fingerprint.
#
# Advantages over Bullet:
# - Zero false positives / false negatives
# - Lighter weight (better for performance-sensitive apps)
# - More accurate detection via logs + stacktraces
#
# Configured for RSpec tests only (not development requests)
gem "prosopite", group: :test
