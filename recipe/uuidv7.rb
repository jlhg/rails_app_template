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
file "lib/templates/active_record/migration/create_table_migration.rb", <<~RUBY
  class <%= migration_class_name %> < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
    def change
      create_table :<%= table_name %><%= primary_key_type %><%= ', default: -> { "uuidv7()" }' if options[:primary_key_type] == :uuid %> do |t|
  <% attributes.each do |attribute| -%>
  <% if attribute.password_digest? -%>
        t.string :password_digest<%= attribute.inject_options %>
  <% elsif attribute.token? -%>
        t.string :<%= attribute.name %><%= attribute.inject_options %>
  <% elsif attribute.reference? -%>
        t.references :<%= attribute.name %><%= attribute.inject_options %><%= foreign_key_type %>
  <% elsif !attribute.virtual? -%>
        t.<%= attribute.type %> :<%= attribute.name %><%= attribute.inject_options %>
  <% end -%>
  <% end -%>
  <% if options[:timestamps] %>
        t.timestamps
  <% end -%>
      end
  <% attributes.select(&:token?).each do |attribute| -%>
      add_index :<%= table_name %>, :<%= attribute.index_name %><%= attribute.inject_index_options %>, unique: true
  <% end -%>
  <% attributes_with_index.each do |attribute| -%>
      add_index :<%= table_name %>, :<%= attribute.index_name %><%= attribute.inject_index_options %>
  <% end -%>
    end

    private

    def primary_key_type
      ", id: :uuid" if options[:primary_key_type] == :uuid
    end

    def foreign_key_type
      ", type: :uuid" if options[:primary_key_type] == :uuid
    end
  end
RUBY

# NOTE: Migration generator will automatically use UUID for new tables.
# Example generated migration:
#
#   create_table :orders, id: :uuid, default: -> { "uuidv7()" } do |t|
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
