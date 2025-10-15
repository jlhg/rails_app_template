orig_db_config = YAML.load_file("config/database.yml", aliases: true)
db_prefix = File.basename(orig_db_config["development"]["database"], "_development")

run "rm config/database.yml"
file "config/database.yml", <<~CODE
  ---
  default: &default
    adapter: postgresql
    encoding: unicode
    # Connection pool size (should match RAILS_MAX_THREADS for optimal performance)
    pool: <%= ENV.fetch('RAILS_MAX_THREADS', 16).to_i %>
    # Database credentials (use ENV for environment config, Docker Secrets for passwords)
    user: <%= ENV.fetch('DATABASE_USER', 'postgres') %>
    host: <%= ENV.fetch('DATABASE_HOST', 'localhost') %>
    port: <%= ENV.fetch('DATABASE_PORT', 5432).to_i %>
    password: <%=
      if ENV['DATABASE_PASSWORD_FILE'] && File.exist?(ENV['DATABASE_PASSWORD_FILE'])
        File.read(ENV['DATABASE_PASSWORD_FILE']).strip
      elsif ENV['DATABASE_PASSWORD']
        ENV['DATABASE_PASSWORD']
      else
        ''
      end
    %>
  development:
    <<: *default
    database: <%= Settings.pg_db_prefix + "_development" %>
  test:
    <<: *default
    database: <%= Settings.pg_db_prefix + "_test" %>
  production:
    <<: *default
    database: <%= Settings.pg_db_prefix + "_production" %>
CODE

# Only store database name prefix in Settings (business logic: project identification)
update_yaml "config/settings.yml", "pg_db_prefix" => db_prefix
