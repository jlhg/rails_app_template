# syntax=docker/dockerfile:1
# Use Debian slim for better jemalloc compatibility and memory optimization
# Note: Alpine + jemalloc can cause segfaults due to musl libc incompatibility
FROM ruby:3.4-slim

# Build arguments (can be overridden during build)
ARG BUNDLE_WITHOUT="development:test"

# Set environment
ENV LANG=C.UTF-8 \
    RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
    RUBY_YJIT_ENABLE=1 \
    RUBYOPT="--enable-frozen-string-literal"

# Enable jemalloc for optimized memory allocation (reduces memory usage by ~75%)
# See docs/MEMORY_OPTIMIZATION.md for details
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

# Optional: Fine-tune jemalloc behavior
# dirty_decay_ms: Release unused memory after 1 second (default: 10s)
# narenas: Limit memory arenas (default: 4 per CPU)
# background_thread: Enable background threads for memory management
ENV MALLOC_CONF="dirty_decay_ms:1000,narenas:2,background_thread:true"

# Install system dependencies including jemalloc
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libjemalloc2 \
    libpq-dev \
    postgresql-client \
    git \
    tzdata \
    curl \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Configure git credentials for private repositories (optional)
# This allows bundler to fetch gems from private GitHub/GitLab repositories
ARG GITLAB_HOST=gitlab.com
RUN --mount=type=secret,id=github_pat \
    --mount=type=secret,id=gitlab_pat \
  git config --global credential.helper store && \
  # GitHub configuration
  if [ -f "/run/secrets/github_pat" ]; then \
    git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" && \
    git config --global --add url."https://github.com/".insteadOf "git@github.com:" && \
    git config --global --add url."https://github.com/".insteadOf "git+ssh://git@github.com/" && \
    GIT_TOKEN=$(cat /run/secrets/github_pat) && \
    echo "https://token:${GIT_TOKEN}@github.com" >> ~/.git-credentials; \
  fi && \
  # GitLab configuration (supports custom host)
  if [ -f "/run/secrets/gitlab_pat" ]; then \
    git config --global url."https://${GITLAB_HOST}/".insteadOf "ssh://git@${GITLAB_HOST}/" && \
    git config --global --add url."https://${GITLAB_HOST}/".insteadOf "git@${GITLAB_HOST}:" && \
    git config --global --add url."https://${GITLAB_HOST}/".insteadOf "git+ssh://git@${GITLAB_HOST}/" && \
    GIT_TOKEN=$(cat /run/secrets/gitlab_pat) && \
    echo "https://oauth2:${GIT_TOKEN}@${GITLAB_HOST}" >> ~/.git-credentials; \
  fi && \
  # Set secure permissions if credentials file exists
  if [ -f ~/.git-credentials ]; then chmod 600 ~/.git-credentials; fi

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' \
    && if [ -n "$BUNDLE_WITHOUT" ]; then \
         bundle config set --local without "$BUNDLE_WITHOUT"; \
       fi \
    && bundle install -j4 \
    && rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git \
    && rm -f ~/.git-credentials

# Copy application code
COPY . .

# Copy and setup entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD curl -f http://localhost:3000/up || exit 1

# Expose port
EXPOSE 3000

# Set entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]

# Default command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
