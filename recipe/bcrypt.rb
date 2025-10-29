# BCrypt - Password Hashing
# https://github.com/bcrypt-ruby/bcrypt-ruby
#
# BCrypt is a sophisticated and secure hash algorithm designed by OpenBSD.
# Used by Rails' has_secure_password for password hashing.
#
# Features:
# - Industry-standard password hashing (used by major platforms)
# - Built-in salt generation
# - Configurable work factor (computational cost)
# - Resistant to rainbow table and brute-force attacks
#
# Usage with Rails:
#   class User < ApplicationRecord
#     has_secure_password
#   end

gem "bcrypt"
