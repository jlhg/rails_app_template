# Replace sqlite3 with pg gem for PostgreSQL
gsub_file "Gemfile", /gem ['"]sqlite3['"].*$/, 'gem "pg"'

# Enhanced database.yml for Docker secrets support
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
    <<: *default

  test:
    <<: *default
    database: <%= ENV.fetch('DATABASE_NAME') { "\#{Rails.application.class.module_parent_name.underscore}_test" } %>

  production:
    <<: *default
YAML

remove_file "config/database.yml"
create_file "config/database.yml", database_yml_content
