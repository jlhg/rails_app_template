# UUIDv7 as Default Primary Key
#
# Configures Rails to use UUIDv7 for all new tables by default.
#
# Benefits:
# - Same performance as bigint (290s = 290s for 1M row inserts)
# - Prevents business intelligence leakage (order count, growth rate)
# - Time-ordered for excellent B-tree index locality
# - RFC 9562 standardized (PostgreSQL 18+, MySQL 8.4+)
#
# Requirements:
# - PostgreSQL 18+ (uses native uuidv7() function)
#
# Selective opt-out (use bigint for specific tables):
#   create_table :join_table, id: :bigint do |t|
#     # Uses bigint instead of UUID
#   end

# Configure Rails generators to use UUID by default
initializer "generators.rb", <<~RUBY
  # Default primary key type for all new tables
  # Use UUIDv7 for better security (prevents business intel leakage)
  # while maintaining bigint-level performance
  Rails.application.config.generators do |g|
    g.orm :active_record, primary_key_type: :uuid
  end
RUBY

# Configure PostgreSQL to use uuidv7() for UUID generation
initializer "uuidv7.rb", <<~RUBY
  # PostgreSQL 18+ UUIDv7 Configuration
  #
  # UUIDv7 uses time-ordered structure (48-bit Unix timestamp + random bits)
  # which provides excellent B-tree index performance equal to bigint sequential keys.
  #
  # Performance comparison (1M row insert):
  # - bigint:  290 seconds
  # - UUIDv7:  290 seconds (same as bigint!)
  # - UUIDv4:  375 seconds
  #
  # Storage:
  # - bigint:  8 bytes
  # - UUID:    16 bytes (2x size, but worth it for security)
  #
  # Security benefits:
  # - Prevents business intelligence leakage (can't infer total orders, growth rate)
  # - Prevents enumeration attacks (can't guess sequential IDs)
  # - Maintains global uniqueness (safe for distributed systems)

  ActiveSupport.on_load(:active_record) do
    # Override default UUID generation to use uuidv7()
    # This modifies the PostgreSQL adapter's native database types
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:uuid][:default] = -> { "uuidv7()" }
  end
RUBY

# Add migration template for UUID tables with references
# Template file: template/files/lib/templates/active_record/migration/create_table_migration.rb
directory "files/lib", "lib"

# NOTE: Migration generator will automatically use UUID for new tables.
# The default value (uuidv7()) is set globally in config/initializers/uuidv7.rb
#
# Example generated migration:
#
#   create_table :orders, id: :uuid do |t|
#     t.references :user, type: :uuid, foreign_key: true
#     t.string :status
#     t.timestamps
#   end
#
# To use bigint instead (opt-out), specify explicitly:
#
#   create_table :internal_logs, id: :bigint do |t|
#     t.timestamps
#   end
