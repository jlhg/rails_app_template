# Replace sqlite3 with pg gem for PostgreSQL
gsub_file "Gemfile", /gem ['"]sqlite3['"].*$/, 'gem "pg"'

# Enhanced database.yml for Docker secrets support and Rails 8.1 multi-database
database_yml_content = <<~YAML
  default: &default
    adapter: postgresql
    encoding: unicode
    # Connection pool size per worker process
    # Each Puma worker maintains its own pool
    # Total connections = WEB_CONCURRENCY × RAILS_MAX_THREADS
    # Ensure PostgreSQL max_connections ≥ total connections + buffer
    pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
    <% if ENV['DATABASE_URL'] %>
    # Use DATABASE_URL if provided (traditional approach)
    url: <%= ENV['DATABASE_URL'] %>
    <% else %>
    # Use individual environment variables (better for Docker secrets)
    host: <%= ENV.fetch('DATABASE_HOST', 'localhost') %>
    port: <%= ENV.fetch('DATABASE_PORT', 5432) %>
    database: <%= ENV.fetch('DATABASE_NAME') { "\#{Rails.application.class.module_parent_name.underscore}_\#{Rails.env}" } %>
    username: <%= ENV.fetch('DATABASE_USER', 'postgres') %>
    <%
      # Read password from file if DATABASE_PASSWORD_FILE is set
      password = if ENV['DATABASE_PASSWORD_FILE'] && File.exist?(ENV['DATABASE_PASSWORD_FILE'])
        File.read(ENV['DATABASE_PASSWORD_FILE']).strip
      elsif ENV['DATABASE_PASSWORD']
        ENV['DATABASE_PASSWORD']
      end
    %>
    <% if password %>
    password: <%= password %>
    <% end %>
    <% end %>

  development:
    primary:
      <<: *default
    queue:
      <<: *default
      migrations_paths: db/queue_migrate
    cache:
      <<: *default
      migrations_paths: db/cache_migrate
    cable:
      <<: *default
      migrations_paths: db/cable_migrate

  test:
    primary:
      <<: *default
      database: <%= ENV.fetch('DATABASE_NAME') { "\#{Rails.application.class.module_parent_name.underscore}_test" } %>
    queue:
      <<: *default
      database: <%= ENV.fetch('DATABASE_NAME') { "\#{Rails.application.class.module_parent_name.underscore}_test" } %>
      migrations_paths: db/queue_migrate
    cache:
      <<: *default
      database: <%= ENV.fetch('DATABASE_NAME') { "\#{Rails.application.class.module_parent_name.underscore}_test" } %>
      migrations_paths: db/cache_migrate
    cable:
      <<: *default
      database: <%= ENV.fetch('DATABASE_NAME') { "\#{Rails.application.class.module_parent_name.underscore}_test" } %>
      migrations_paths: db/cable_migrate

  production:
    primary:
      <<: *default
    queue:
      <<: *default
      # Solid Queue can use same database as primary
      # Alternative: use separate database by setting different DATABASE_NAME
      database: <%= ENV.fetch('DATABASE_NAME') { "\#{Rails.application.class.module_parent_name.underscore}_\#{Rails.env}" } %>
      migrations_paths: db/queue_migrate
    cache:
      <<: *default
      # Solid Cache can use same database as primary
      database: <%= ENV.fetch('DATABASE_NAME') { "\#{Rails.application.class.module_parent_name.underscore}_\#{Rails.env}" } %>
      migrations_paths: db/cache_migrate
    cable:
      <<: *default
      # Solid Cable can use same database as primary
      database: <%= ENV.fetch('DATABASE_NAME') { "\#{Rails.application.class.module_parent_name.underscore}_\#{Rails.env}" } %>
      migrations_paths: db/cable_migrate
YAML

remove_file "config/database.yml"
create_file "config/database.yml", database_yml_content
