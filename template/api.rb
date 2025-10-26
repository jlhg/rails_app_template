ARGS = ARGV.join(" ").scan(/--?([^=\s]+)\s*(?:=?([^\s-]+))?/).to_h

def source_paths
  [*super, __dir__]
end

require_relative "../lib/base"

# Ensure Ruby version is 3.4+ (this template is optimized for Ruby 3.4)
# Use current Ruby version if 3.4+, otherwise default to 3.4.0
ruby_version = Gem::Version.new(RUBY_VERSION)
required_version = Gem::Version.new("3.4.0")

if ruby_version < required_version
  say "Warning: This template is optimized for Ruby 3.4+", :yellow
  say "   Current Ruby version: #{RUBY_VERSION}", :yellow
  say "   Please consider upgrading to Ruby 3.4 or later", :yellow
end

remove_file ".ruby-version"
create_file ".ruby-version", RUBY_VERSION

# Replace default .gitignore with enhanced version
remove_file ".gitignore"
copy_file "files/.gitignore_template", ".gitignore"

# Replace Rails 8 default .rubocop.yml with custom configuration
remove_file ".rubocop.yml"
copy_file "files/.rubocop.yml", ".rubocop.yml"

# Add .dockerignore for Docker deployments
# Rails 8.1+ creates .dockerignore by default, so we need to remove it first
remove_file ".dockerignore"
copy_file "files/.dockerignore_template", ".dockerignore"

# Add Docker compose template
copy_file "files/compose.yaml", "compose.yaml"

# Add Docker compose local development example
copy_file "files/compose.local.yaml.example", "compose.local.yaml.example"

# Add Dockerfile template
# Rails 8.1+ creates Dockerfile by default, so we need to remove it first
remove_file "Dockerfile"
copy_file "files/Dockerfile", "Dockerfile"

# Add Docker entrypoint script (Rails 8.1+ convention: bin/docker-entrypoint)
copy_file "files/docker-entrypoint.sh", "bin/docker-entrypoint"
chmod "bin/docker-entrypoint", 0755

# Add .env.example for environment configuration
copy_file "files/.env.example", ".env.example"

# Add .env.local.example for local development (non-Docker)
copy_file "files/.env.local.example", ".env.local.example"

# Create .secrets directory for Docker secrets with proper permissions
directory "files/.secrets", ".secrets"

# Add Docker management rake tasks
copy_file "files/docker.rake", "lib/tasks/docker.rake"

# Set secure permissions for .secrets directory
# 700: Only owner can read/write/execute (prevents other users from listing)
# This is required for Docker Compose to properly mount secrets
after_bundle do
  run "chmod 700 .secrets" if File.directory?(".secrets")

  # Set 640 permissions for secret files (owner: rw, group: r, others: none)
  # This allows Docker daemon (usually in docker group) to read secrets
  # while preventing unauthorized access
  Dir.glob(".secrets/*").each do |file|
    next if File.basename(file).end_with?(".example", ".gitkeep")

    run "chmod 640 #{file}" if File.file?(file)
  end
end

# Set test environment to use :test queue adapter
environment "config.active_job.queue_adapter = :test", env: "test"

init_gem "aasm"
init_gem "pagy"
init_gem "redis"
init_gem "redis-objects"
init_gem "rubocop"
init_gem "rubocop-rails"
init_gem "rubocop-rspec"
init_gem "bcrypt"
init_gem "benchmark-ips"
init_gem "alba"
init_gem "rack-attack"
init_gem "sentry"
init_gem "jwt"
init_gem "pundit"
# init_gem "rails-i18n"
recipe "rspec"
recipe "config"
recipe "sentry"
recipe "database_yml"
recipe "uuidv7"
recipe "action_storage"
recipe "action_cable"
# recipe "google-cloud-storage"

run "bundle install"
