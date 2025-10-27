# Secrets Directory

This directory stores sensitive credentials for the API documentation service.

## Setup

### Cloudflare Tunnel Token

If you want to expose your API documentation via Cloudflare Tunnel:

1. **Create a Cloudflare Tunnel**:
   - Go to https://one.dash.cloudflare.com/
   - Navigate to: Access → Tunnels
   - Click "Create a tunnel"
   - Give it a name (e.g., "api-docs")
   - Copy the tunnel credentials JSON

2. **Save credentials**:
   ```bash
   # Copy the example file
   cp .secrets/cf_tunnel_token.example .secrets/cf_tunnel_token

   # Edit and paste your actual credentials
   nano .secrets/cf_tunnel_token
   ```

3. **Set permissions** (recommended):
   ```bash
   chmod 600 .secrets/cf_tunnel_token
   ```

4. **Update configuration**:
   ```bash
   # Copy and edit cloudflared config
   cp cloudflared-config.yaml.example cloudflared-config.yaml

   # Update tunnel ID and hostname
   nano cloudflared-config.yaml
   ```

5. **Start with Cloudflare profile**:
   ```bash
   docker compose --profile cloudflare up -d
   ```

## Security Notes

- **Never commit actual secrets** to git (`.secrets/` is in .gitignore)
- Only commit `.example` files with placeholder values
- Use `chmod 600` or `chmod 640` for secret files
- Rotate credentials periodically
- Use Cloudflare Access to add authentication layer

## File Permissions

Recommended permissions for Docker Compose secrets:

```bash
# Directory permissions
chmod 700 .secrets/

# File permissions (owner read/write only)
chmod 600 .secrets/cf_tunnel_token

# Or if Docker needs to read (owner rw, group r)
chmod 640 .secrets/cf_tunnel_token
```

## Without Cloudflare Tunnel

If you don't need Cloudflare Tunnel, you can:
- Simply run `docker compose up` (without `--profile cloudflare`)
- Access documentation locally at http://localhost:8080
- No secrets needed
