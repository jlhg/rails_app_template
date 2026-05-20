# Rails Application

Rails 8.1 API application using Valkey (Redis-compatible) for caching, session storage, WebSocket (ActionCable), and background jobs (Sidekiq).

## Architecture

- Framework: Ruby on Rails 8.1 (API mode)
- Database: PostgreSQL 18
- Cache: Valkey (redis_cache)
- Background Jobs: Sidekiq (redis_queue)
- WebSocket: ActionCable with Valkey adapter (redis_cable)
- Session Storage: Valkey (redis_session)
- Static Assets: Cloudflare R2 (static.somanext.com)

## Setup

### Code Quality

```sh
# Install dependencies
bundle install

# Run RuboCop with auto-correct
bin/rubocop -A
```

### Security Testing

```sh
bin/brakeman
```

### Development Environment

Copy `.env.example` to `.env` and configure settings.

Create Docker secrets in `.secrets/` (see `.env.example` for required secrets):

```sh
# Create .secrets directory and files
mkdir -p .secrets
openssl rand -hex 64 > .secrets/rails_secret_key_base
printf "your_smtp_password" > .secrets/mailer_smtp_password
printf "your_cloudflare_tunnel_token" > .secrets/cf_tunnel_token
```

Build Docker images and start services:

```sh
docker compose build
docker compose up -d
```

Database migrations run automatically on container startup by default (`APP_DB_MIGRATION=true`). Set to `false` in `.env` to disable.

When developing with database schema changes, update `db/structure.sql` using one-time containers with volume mount:

```sh
docker compose run --rm -v $(pwd)/db:/rails/db server bin/rails db:migrate
```

The `-v $(pwd)/db:/rails/db` flag syncs `structure.sql` changes back to host.

### Test Environment

The test environment uses PostgreSQL and Valkey (Redis-compatible) to test against real backing services rather than in-memory stubs.

```sh
docker compose -f compose.test.yaml run --rm --build server bin/rspec
```

### Production Environment

The production environment runs on Docker Swarm for orchestration and high availability.

Copy `.env.example` to `.env.prod` and configure settings.

Create Docker networks:

```sh
docker network create --driver overlay --attachable <app_name>
```

Create Docker Swarm secrets (see `.env.example` for all required secrets):

```sh
# Example: Create secrets from stdin
printf "your_password" | docker secret create <app_name>_pg_password -
openssl rand -hex 64 | docker secret create <app_name>_rails_secret_key_base -

# Required secrets: pg_password, redis_cache_password, redis_cable_password,
# redis_session_password, redis_queue_password, rails_secret_key_base,
# mailer_smtp_password, cf_tunnel_token
```

Deploy the stack:

```sh
# Build Docker image
bin/deploy build

# Deploy services
bin/deploy up

# Or build and deploy together
bin/deploy up --build

# Check service status
bin/deploy status

# View service logs
bin/deploy logs server
bin/deploy logs worker

# Restart services
bin/deploy restart

# Remove stack
bin/deploy down
```

For more deployment options, run `bin/deploy --help`.

## Resources

- [OpenAPI Documentation](docs/openapi)
- [Logging](docs/logging.md)
