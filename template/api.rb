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
copy_file from_files(".gitignore_template"), ".gitignore"

# Replace Rails 8 default .rubocop.yml with custom configuration
remove_file ".rubocop.yml"
copy_file from_files(".rubocop.yml"), ".rubocop.yml"

# Add .dockerignore for Docker deployments
# Rails 8.1+ creates .dockerignore by default, so we need to remove it first
remove_file ".dockerignore"
copy_file from_files(".dockerignore_template"), ".dockerignore"

# Add Docker compose template
copy_file from_files("compose.yaml"), "compose.yaml"

# Add Docker compose override example for development
copy_file from_files("compose.override.yaml.example"), "compose.override.yaml.example"

# Add Dockerfile template
# Rails 8.1+ creates Dockerfile by default, so we need to remove it first
remove_file "Dockerfile"
copy_file from_files("Dockerfile"), "Dockerfile"

# Add Docker entrypoint script (Rails 8.1+ convention: bin/docker-entrypoint)
# Rails 8.1+ creates bin/docker-entrypoint by default, so we need to remove it first
remove_file "bin/docker-entrypoint"
copy_file from_files("docker-entrypoint.sh"), "bin/docker-entrypoint"
chmod "bin/docker-entrypoint", 0755

# Add .env.example for environment configuration
copy_file from_files(".env.example"), ".env.example"

# Create .secrets directory for Docker secrets with proper permissions
directory from_files(".secrets"), ".secrets"

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

# Core recipes (gems with installation and configuration)
recipe "aasm"
recipe "alba"
recipe "bcrypt"
recipe "benchmark"
recipe "config"
recipe "jwt"
recipe "pagy"
recipe "pundit"
recipe "rack_attack"
recipe "redis"
recipe "rspec"
recipe "rubocop"
recipe "sentry"

# Configuration recipes (environment-specific settings)
recipe "config/action_mailer"
recipe "config/cors"
recipe "config/log"
recipe "config/puma"
recipe "config/time_zone"

# Application-wide configuration (all environments)
environment <<~RUBY
  # Silence healthcheck logs
  config.silence_healthcheck_path = "/up"

  # Allow additional hosts from environment variable
  # Configure via ALLOWED_HOSTS env var (comma-separated)
  # Example: ALLOWED_HOSTS="example.com,test.example.com,dev.example.com"
  # Useful for Cloudflare Tunnel, ngrok, or custom domains
  allowed_hosts = ENV.fetch("ALLOWED_HOSTS", "").split(",").map(&:strip).reject(&:empty?)
  allowed_hosts.each { |host| config.hosts << host } unless allowed_hosts.empty?
RUBY

recipe "database_yml"
recipe "uuidv7"
recipe "action_storage"

# Set up basic route structure
# Health check endpoint at root level (outside API scope)
route 'get "up" => "rails/health#show", as: :health_check'

# Create API scope for all API endpoints
inject_into_file "config/routes.rb", after: "Rails.application.routes.draw do\n" do
  <<~RUBY
    scope path: "/api", as: "api" do
      # API routes go here
    end

  RUBY
end

recipe "action_cable"
recipe "openapi_doc"
# recipe "google-cloud-storage"

run "bundle install"

# Auto-fix code style issues with RuboCop
# This ensures the generated project follows RuboCop style guidelines
say "Running RuboCop auto-corrections..."
run "bundle exec rubocop -A"
