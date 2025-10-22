ARGS = ARGV.join(" ").scan(/--?([^=\s]+)\s*(?:=?([^\s-]+))?/).to_h

def source_paths
  [*super, __dir__]
end

require_relative "../lib/base"

# Replace default .gitignore with enhanced version
remove_file ".gitignore"
copy_file "files/.gitignore_template", ".gitignore"

# Add .dockerignore for Docker deployments
copy_file "files/.dockerignore_template", ".dockerignore"

# Add Docker compose template
copy_file "files/compose.yaml", "compose.yaml"

# Add Docker compose local development example
copy_file "files/compose.local.yaml.example", "compose.local.yaml.example"

# Add Dockerfile template
copy_file "files/Dockerfile", "Dockerfile"

# Add Docker entrypoint script
copy_file "files/docker-entrypoint.sh", "docker-entrypoint.sh"

# Add .env.example for environment configuration
copy_file "files/.env.example", ".env.example"

# Add .env.local.example for local development (non-Docker)
copy_file "files/.env.local.example", ".env.local.example"

# Create .secrets directory for Docker secrets with proper permissions
directory "files/.secrets", ".secrets"

# Copy documentation files
directory "files/docs", "docs"

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
init_gem "bcrypt"
init_gem "benchmark-ips"
init_gem "alba"
init_gem "rack-attack"
init_gem "jwt"
init_gem "pundit"
# init_gem "rails-i18n"
recipe "rspec"
recipe "config"
recipe "database_yml"
recipe "uuidv7"
recipe "action_storage"
recipe "action_cable"
# recipe "google-cloud-storage"

run "bundle install"
