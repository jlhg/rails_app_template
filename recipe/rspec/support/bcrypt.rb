# frozen_string_literal: true

# The default cost factor used by bcrypt-ruby is 12, which is fine for production.
# Use lower cost factor in test environment for better performance (10x faster).
BCrypt::Engine.cost = 3
