# Docker Compose Management Tasks
#
# Usage:
#   rake docker:build              # Build production image
#   rake docker:build[local]       # Build local development image
#   rake docker:up                 # Start production containers
#   rake docker:up[local]          # Start local development containers
#   rake docker:down               # Stop and remove containers
#   rake docker:restart            # Restart containers
#   rake docker:logs               # View container logs
#   rake docker:ps                 # List running containers
#   rake docker:shell              # Open shell in web container
#   rake docker:console            # Open Rails console
#   rake docker:setup              # Initial setup (create secrets)
#   rake docker:clean              # Clean up everything (DANGEROUS)
#
# Environment:
#   - default: compose.yaml (production-like)
#   - local:   compose.yaml + compose.local.yaml (development)

namespace :docker do
  # Helper method to determine compose files
  def compose_files(env = nil)
    case env&.to_s
    when "local", "development", "dev"
      "-f compose.yaml -f compose.local.yaml"
    else
      "" # Use default compose.yaml
    end
  end

  # Helper method to get git commit SHA
  def git_revision
    `git rev-parse --short HEAD 2>/dev/null`.strip
  end

  # Helper method to run docker compose command
  def docker_compose(command, env = nil)
    files = compose_files(env)
    sh "docker compose #{files} #{command}"
  end

  desc "Build Docker image (usage: rake docker:build or docker:build[local])"
  task :build, [:env] => :environment do |_t, args|
    env = args[:env]
    revision = git_revision

    if revision.empty?
      puts "Warning: No git repository found, building without REVISION"
      docker_compose("build", env)
    else
      puts "Building Docker image with REVISION=#{revision}"
      sh "REVISION=#{revision} docker compose #{compose_files(env)} build"
    end
  end

  desc "Start containers (usage: rake docker:up or docker:up[local])"
  task :up, [:env] => :environment do |_t, args|
    env = args[:env]
    puts "Starting containers..."
    docker_compose("up -d", env)
    puts "Containers started. Run 'rake docker:logs' to view logs"
  end

  desc "Stop and remove containers"
  task :down, [:env] => :environment do |_t, args|
    env = args[:env]
    puts "Stopping containers..."
    docker_compose("down", env)
    puts "Containers stopped"
  end

  desc "Restart containers"
  task :restart, [:env] => :environment do |_t, args|
    env = args[:env]
    puts "Restarting containers..."
    docker_compose("restart", env)
    puts "Containers restarted"
  end

  desc "View container logs (usage: docker:logs or docker:logs[local,web])"
  task :logs, [:env, :service] => :environment do |_t, args|
    env = args[:env]
    service = args[:service] || ""
    docker_compose("logs -f #{service}", env)
  end

  desc "List running containers"
  task :ps, [:env] => :environment do |_t, args|
    env = args[:env]
    docker_compose("ps", env)
  end

  desc "Open shell in web container"
  task :shell, [:env] => :environment do |_t, args|
    env = args[:env]
    docker_compose("exec web bash", env)
  end

  desc "Open Rails console"
  task :console, [:env] => :environment do |_t, args|
    env = args[:env]
    docker_compose("exec web bundle exec rails console", env)
  end

  desc "Run database migrations"
  task :migrate, [:env] => :environment do |_t, args|
    env = args[:env]
    puts "Running database migrations..."
    docker_compose("exec web bundle exec rails db:migrate", env)
  end

  desc "Initial setup (create secrets, prepare database)"
  task setup: :environment do
    puts "Running initial setup..."

    # Check if .secrets directory exists
    unless Dir.exist?(".secrets")
      puts "Error: .secrets directory not found"
      puts "Please create .secrets directory first"
      exit 1
    end

    # Generate secrets if they don't exist
    secrets = [
      "database_password",
      "redis_cache_password",
      "redis_cable_password",
      "redis_session_password",
      "rails_secret_key_base"
    ]

    secrets.each do |secret|
      secret_file = ".secrets/#{secret}"
      next if File.exist?(secret_file)

      puts "Generating #{secret}..."
      if secret == "rails_secret_key_base"
        # Generate Rails secret
        secret_value = `bundle exec rails secret 2>/dev/null`.strip
        if secret_value.empty?
          # Fallback if rails command not available
          secret_value = `openssl rand -base64 64`.strip
        end
      else
        # Generate random password
        secret_value = `openssl rand -base64 32`.strip
      end

      File.write(secret_file, secret_value)
      File.chmod(0o640, secret_file)
      puts "Created #{secret_file}"
    end

    # Set proper permissions
    puts "Setting proper permissions..."
    sh "chmod 700 .secrets"
    sh "chmod 640 .secrets/*_password .secrets/*_base 2>/dev/null || true"

    puts ""
    puts "Setup complete!"
    puts ""
    puts "Next steps:"
    puts "  1. rake docker:build          # Build Docker image"
    puts "  2. rake docker:up             # Start containers"
    puts "  3. rake docker:db:prepare     # Prepare database (first time only)"
  end

  desc "Clean up everything (DANGEROUS: removes volumes)"
  task :clean, [:env] => :environment do |_t, args|
    env = args[:env]
    print "Warning: This will remove all containers, volumes, and data. Continue? (y/N): "
    response = $stdin.gets.chomp
    if response.downcase == "y"
      puts "Cleaning up..."
      docker_compose("down -v", env)
      sh "rm -rf .srv" if Dir.exist?(".srv")
      puts "Cleanup complete"
    else
      puts "Cancelled"
    end
  end

  # Database tasks
  namespace :db do
    desc "Prepare database (create + migrate)"
    task :prepare, [:env] => :environment do |_t, args|
      env = args[:env]
      puts "Preparing database..."
      sh "RAILS_DB_PREPARE=true docker compose #{compose_files(env)} restart web"
      puts "Database prepared"
    end

    desc "Create database"
    task :create, [:env] => :environment do |_t, args|
      env = args[:env]
      docker_compose("exec web bundle exec rails db:create", env)
    end

    desc "Drop database"
    task :drop, [:env] => :environment do |_t, args|
      env = args[:env]
      print "Warning: This will delete all data. Continue? (y/N): "
      response = $stdin.gets.chomp
      if response.downcase == "y"
        docker_compose("exec web bundle exec rails db:drop", env)
      else
        puts "Cancelled"
      end
    end

    desc "Reset database (drop + create + migrate)"
    task :reset, [:env] => :environment do |_t, args|
      env = args[:env]
      print "Warning: This will delete all data and recreate database. Continue? (y/N): "
      response = $stdin.gets.chomp
      if response.downcase == "y"
        docker_compose("exec web bundle exec rails db:reset", env)
      else
        puts "Cancelled"
      end
    end

    desc "Seed database"
    task :seed, [:env] => :environment do |_t, args|
      env = args[:env]
      docker_compose("exec web bundle exec rails db:seed", env)
    end
  end

  # Rails tasks
  namespace :rails do
    desc "Open Rails console"
    task :console, [:env] => :environment do |_t, args|
      Rake::Task["docker:console"].invoke(args[:env])
    end

    desc "Run Rails command (usage: docker:rails:run[local,'db:migrate'])"
    task :run, [:env, :command] => :environment do |_t, args|
      env = args[:env]
      command = args[:command] || ""
      if command.empty?
        puts "Error: Please provide a command"
        puts "Usage: rake docker:rails:run[local,'db:migrate']"
        exit 1
      end
      docker_compose("exec web bundle exec rails #{command}", env)
    end
  end

  # Test tasks
  namespace :test do
    desc "Run RSpec tests"
    task :rspec, [:env, :path] => :environment do |_t, args|
      env = args[:env] || "local"
      path = args[:path] || ""
      docker_compose("exec web bundle exec rspec #{path}", env)
    end

    desc "Run RuboCop"
    task :rubocop, [:env] => :environment do |_t, args|
      env = args[:env] || "local"
      docker_compose("exec web bundle exec rubocop", env)
    end
  end

  # Utility tasks
  desc "Show Docker Compose configuration"
  task :config, [:env] => :environment do |_t, args|
    env = args[:env]
    docker_compose("config", env)
  end

  desc "Pull latest images"
  task :pull, [:env] => :environment do |_t, args|
    env = args[:env]
    docker_compose("pull", env)
  end

  desc "Show all available tasks"
  task help: :environment do
    puts <<~HELP
      Docker Compose Management Tasks
      ================================

      Environment:
        [env] - Optional environment argument
                (omit for production, use 'local' for development)

      Basic Commands:
        rake docker:build[env]          Build Docker image
        rake docker:up[env]             Start containers
        rake docker:down[env]           Stop containers
        rake docker:restart[env]        Restart containers
        rake docker:logs[env,service]   View logs (optionally for specific service)
        rake docker:ps[env]             List running containers

      Development:
        rake docker:shell[env]          Open bash shell in web container
        rake docker:console[env]        Open Rails console

      Database:
        rake docker:db:prepare[env]     Prepare database (first time)
        rake docker:db:create[env]      Create database
        rake docker:db:reset[env]       Reset database (DANGEROUS)
        rake docker:db:seed[env]        Seed database
        rake docker:migrate[env]        Run migrations

      Testing (requires local environment):
        rake docker:test:rspec[local,path]    Run RSpec tests
        rake docker:test:rubocop[local]       Run RuboCop

      Utilities:
        rake docker:setup               Initial setup (create secrets)
        rake docker:clean[env]          Clean up everything (DANGEROUS)
        rake docker:config[env]         Show Docker Compose config
        rake docker:pull[env]           Pull latest images

      Examples:
        rake docker:build                      # Build production image
        rake docker:build[local]               # Build local image
        rake docker:up[local]                  # Start local environment
        rake docker:logs[local,web]            # View web service logs
        rake docker:test:rspec[local,spec/models]  # Run model tests
    HELP
  end
end

# Default task shows help
task docker: "docker:help"
