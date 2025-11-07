#!/bin/bash -e

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
rm -f /rails/tmp/pids/server.pid

# Set secrets from files
set_secret "SECRET_KEY_BASE" "APP_SECRET_KEY_BASE_FILE"

# Database preparation (optional, controlled by RAILS_DB_PREPARE)
if [ "${APP_RAILS_DB_PREPARE:-false}" = "true" ]; then
  if command -v pg_isready > /dev/null 2>&1; then
    until pg_isready -h "${APP_POSTGRES_HOST}" -U "${APP_POSTGRES_USER}" > /dev/null 2>&1; do
      echo "Waiting for PostgreSQL to be ready..."
      sleep 2
    done
    echo "PostgreSQL is ready!"
  fi

  # Run database preparation (creates DB if needed, runs migrations)
  echo "Running database preparation..."
  ./bin/rails db:prepare
fi

# Execute the main command (use exec to replace shell process)
exec "${@}"
