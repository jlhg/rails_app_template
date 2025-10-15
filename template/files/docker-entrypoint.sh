#!/bin/bash
set -e

# Helper function to read secret from file
# Usage: read_secret ENV_VAR_NAME FILE_ENV_VAR_NAME
read_secret() {
  local var_name="$1"
  local file_var_name="$2"

  # Only process if *_FILE env var is set
  if [ -n "${!file_var_name}" ]; then
    local secret_file="${!file_var_name}"

    # Read from file if exists and env var not already set
    if [ -z "${!var_name}" ] && [ -f "$secret_file" ]; then
      export "$var_name"="$(cat "$secret_file")"
    fi
  fi
}

# Remove pre-existing server.pid for Rails
rm -f /app/tmp/pids/server.pid

# Load secrets from files (only if *_FILE variables are set)
read_secret "SECRET_KEY_BASE" "SECRET_KEY_BASE_FILE"
read_secret "DATABASE_PASSWORD" "DATABASE_PASSWORD_FILE"
read_secret "REDIS_PASSWORD" "REDIS_PASSWORD_FILE"

# Wait for database to be ready (simple check)
until pg_isready -h "${DATABASE_HOST:-pg}" -U "${DATABASE_USER:-postgres}" > /dev/null 2>&1; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done

echo "PostgreSQL is ready!"

# Run database migrations only if RAILS_DB_PREPARE is set
if [ "${RAILS_DB_PREPARE:-false}" = "true" ]; then
  echo "Running database preparation..."
  bundle exec rails db:prepare
fi

# Execute the main command (use exec to replace shell process)
exec "$@"
