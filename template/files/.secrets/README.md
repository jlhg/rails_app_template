# Docker Secrets Directory

This directory stores sensitive credentials for Docker services.

## Required Files

1. **database_password** - PostgreSQL database password
2. **redis_cache_password** - Redis Cache (Rails.cache, rate limiting)
3. **redis_cable_password** - Redis Cable (ActionCable WebSocket pub/sub)
4. **redis_session_password** - Redis Session (Access tokens, user sessions)
5. **rails_secret_key_base** - Rails encryption key
6. **mailer_smtp_password** - SMTP password for Action Mailer
7. **cf_tunnel_token** (optional) - Cloudflare Tunnel credentials JSON
8. **github_pat** (optional) - GitHub Personal Access Token for private repositories
9. **gitlab_pat** (optional) - GitLab Personal Access Token for private repositories

## Setup Instructions

### Quick Setup

```bash
# 1. Copy example files
for file in *.example; do cp "$file" "${file%.example}"; done

# 2. Generate secure passwords
openssl rand -base64 32 > database_password
openssl rand -base64 32 > redis_cache_password
openssl rand -base64 32 > redis_cable_password
openssl rand -base64 32 > redis_session_password

# 3. Generate Rails secret
cd ..
rails secret > .secrets/rails_secret_key_base
cd .secrets

# 4. Configure SMTP password (get from your email service provider)
# See mailer_smtp_password.example for instructions

# 5. Set proper permissions (REQUIRED)
chmod 700 .
chmod 640 database_password redis_*_password rails_secret_key_base mailer_smtp_password
```

## File Permissions

**IMPORTANT:** Use 640 permissions, NOT 600!

```bash
# Directory permissions
drwx------  (700)  .secrets/

# File permissions
-rw-r-----  (640)  database_password
-rw-r-----  (640)  redis_cache_password
-rw-r-----  (640)  redis_cable_password
-rw-r-----  (640)  redis_session_password
-rw-r-----  (640)  rails_secret_key_base
-rw-r-----  (640)  mailer_smtp_password
-rw-r-----  (640)  cf_tunnel_token
-rw-r-----  (640)  github_pat
-rw-r-----  (640)  gitlab_pat
```

### Why 640 instead of 600?

- **600 causes permission errors** - Docker daemon cannot read the files
- **640 is secure** - Owner can read/write, docker group can read, others cannot
- **Works with non-root containers** - Cloudflared runs as UID 65532 (nonroot)
- **Industry standard** - Recommended for Docker Compose secrets

**Technical details:**
- Cloudflared uses distroless base image running as UID 65532 (nonroot user)
- Docker Compose needs to read secrets from host as docker group
- Secrets are mounted read-only in container at /run/secrets/
- Container's nonroot user (65532) reads from mounted secret

## Security Notes

✅ **Safe:**
- Directory is 700 (only owner can list files)
- Files are 640 (group read-only)
- All files are gitignored
- Docker mounts secrets as read-only in containers

❌ **Never:**
- Commit these files to git
- Use 644 or 777 permissions (world-readable)
- Share secrets via email or chat
- Store in unencrypted backups

## Troubleshooting

### Permission Denied Errors

If you see "permission denied" errors:

```bash
# Check current permissions
ls -la .secrets/

# Fix directory permissions
chmod 700 .secrets

# Fix file permissions (NOT 600!)
chmod 640 .secrets/database_password
chmod 640 .secrets/redis_*_password
chmod 640 .secrets/rails_secret_key_base
```

### Cloudflare Tunnel Setup (Optional)

If you want to expose your app to the internet using Cloudflare Tunnel:

```bash
# 1. Create a tunnel at: https://one.dash.cloudflare.com/
#    Navigate to: Access → Tunnels → Create a tunnel
#    Give it a name (e.g., "my-rails-app")

# 2. Download the tunnel credentials JSON
#    After creating the tunnel, Cloudflare will show credentials
#    It's a JSON file that looks like:
#    {
#      "AccountTag": "...",
#      "TunnelSecret": "...",
#      "TunnelID": "..."
#    }

# 3. Save the entire JSON to cf_tunnel_token
cd .secrets
cat > cf_tunnel_token << 'EOF'
{
  "AccountTag": "your-account-tag-here",
  "TunnelSecret": "your-tunnel-secret-here",
  "TunnelID": "your-tunnel-id-here"
}
EOF
chmod 640 cf_tunnel_token
cd ..

# 4. Copy and configure cloudflared-config.yaml
cp cloudflared-config.yaml.example cloudflared-config.yaml
# Edit cloudflared-config.yaml:
#   - Replace YOUR_TUNNEL_ID_HERE with your Tunnel ID
#   - Replace api.yourdomain.com with your domain
#   - Configure ingress rules as needed

# 5. Start with cloudflare profile
docker compose --profile cloudflare up -d
```

**IMPORTANT:** The `cf_tunnel_token` file contains the credentials JSON (not a simple token string).

### Cloudflared Container Errors

If cloudflared cannot start:

```bash
# 1. Verify credentials file exists and has correct permissions
ls -l .secrets/cf_tunnel_token
# Should show: -rw-r----- (640)

# 2. Verify credentials file is valid JSON
cat .secrets/cf_tunnel_token | jq .
# Should parse without errors

# 3. Verify cloudflared-config.yaml exists
ls -l cloudflared-config.yaml

# 4. Check cloudflared logs
docker compose logs cloudflared

# 5. Fix permissions if needed
chmod 640 .secrets/cf_tunnel_token
```

### Private Repository Access

If your Gemfile references private GitHub/GitLab repositories:

**For GitHub:**
```bash
# 1. Create Personal Access Token at:
# https://github.com/settings/tokens
# Required scope: repo (Full control of private repositories)

# 2. Save token to file
echo "ghp_YOUR_TOKEN_HERE" > github_pat
chmod 640 github_pat

# 3. Rebuild Docker image
docker compose build
```

**For GitLab:**
```bash
# 1. Create Personal Access Token at:
# https://gitlab.com/-/user_settings/personal_access_tokens
# (or your self-hosted GitLab instance)
# Required scopes: read_api, read_repository

# 2. Save token to file
cd .secrets
echo "glpat-YOUR_TOKEN_HERE" > gitlab_pat
chmod 640 gitlab_pat
cd ..

# 3. For self-hosted GitLab, configure custom host
cp .env.example .env
# Edit .env and set: GITLAB_HOST=git.mycompany.com

# 4. Rebuild Docker image
docker compose build
```

**Note:** These tokens are only used during Docker build process to fetch private gems. They are automatically cleaned up after bundle install completes.
