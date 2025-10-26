# OpenAPI Documentation

This directory contains the OpenAPI 3.1.0 specification for your API, along with a standalone documentation service using Docker.

## Quick Start

### Run Documentation Service

```bash
cd docs/openapi
docker compose up
```

Access the documentation:
- **Swagger UI**: http://localhost:8080/swagger.html (Interactive API testing)
- **ReDoc**: http://localhost:8080/redoc.html (Beautiful documentation)
- **Entry Page**: http://localhost:8080

### Stop Documentation Service

```bash
docker compose down
```

## Directory Structure

```
docs/openapi/
├── Dockerfile              # nginx:1.27-alpine with embedded configuration
├── compose.yaml            # Docker Compose configuration
├── .dockerignore           # Files excluded from Docker image
├── .gitignore              # Files excluded from git
├── spec.yaml               # Main OpenAPI specification file
├── index.html              # Documentation entry page
├── swagger.html            # Swagger UI interface
├── redoc.html              # ReDoc interface
├── attributes/             # Custom attribute definitions (extend as needed)
├── parameters/             # Reusable parameter definitions
│   ├── id.yaml            # UUID path parameter
│   └── pagination.yaml    # Pagination query parameters
├── request_bodies/         # Reusable request body definitions
│   └── resource.yaml      # Resource creation/update bodies
├── responses/              # Reusable response definitions
│   ├── success.yaml       # Success response formats
│   ├── error.yaml         # Error response formats
│   └── not_found.yaml     # 404 response
└── schemas/                # Data model schemas
    ├── resource.yaml      # Example resource model
    ├── error.yaml         # Error response schema
    └── metadata.yaml      # Pagination metadata schema
```

## Features

### Production-Ready nginx Configuration

The Dockerfile uses **nginx 1.27-alpine** with optimized settings:

- **Performance optimizations**: sendfile, tcp_nopush, tcp_nodelay
- **Compression**: gzip enabled for YAML, JSON, CSS, JS files
- **CORS enabled**: Allows cross-origin requests for API testing
- **Proper MIME types**: YAML files served with correct content-type
- **Cache control**: Documentation always fresh (no-cache headers)
- **Log persistence**: Access and error logs saved to `.srv/nginx/log/`

### Live Editing

The Docker Compose configuration mounts the current directory as read-only volume:

```yaml
volumes:
  - ./:/app:ro  # Changes reflected immediately
```

Edit any YAML, HTML, or documentation file - just refresh your browser to see updates.

### Log Access

nginx logs are persisted to `.srv/nginx/log/` directory:

```bash
# View access logs
tail -f .srv/nginx/log/access.log

# View error logs
tail -f .srv/nginx/log/error.log
```

## Customizing Your API Documentation

### 1. Update API Information

Edit `spec.yaml` to customize your API details:

```yaml
info:
  title: Your API Name
  version: 1.0.0
  description: Your API description
```

### 2. Add New Endpoints

Add new paths in `spec.yaml`:

```yaml
paths:
  /your-endpoint:
    get:
      summary: Your endpoint description
      # ... endpoint details
```

### 3. Create Reusable Components

**Add a new schema** (`schemas/your_model.yaml`):
```yaml
type: object
properties:
  id:
    type: string
    format: uuid
  # ... other properties
```

**Add a new response** (`responses/your_response.yaml`):
```yaml
description: Your response description
content:
  application/json:
    schema:
      $ref: "../schemas/your_model.yaml"
```

**Reference in spec.yaml**:
```yaml
responses:
  200:
    $ref: "responses/your_response.yaml"
```

### 4. Configure Authentication

The template includes JWT Bearer authentication. To use a different method, edit the `securitySchemes` section in `spec.yaml`:

```yaml
components:
  securitySchemes:
    ApiKeyAuth:
      type: apiKey
      in: header
      name: X-API-Key
```

## Best Practices

### Modular Organization

- Keep components in separate files for better maintainability
- Use `$ref` to reference reusable components
- Group related endpoints using tags

### Documentation Quality

- Provide clear descriptions for all endpoints
- Include examples for request/response bodies
- Document all error cases
- Keep the documentation in sync with your actual API

### Development Workflow

1. **Design First**: Define your API in `spec.yaml` before implementation
2. **Keep in Sync**: Update documentation when API changes
3. **Review Regularly**: Use Swagger UI to test the documentation
4. **Validate**: Use OpenAPI validators to ensure spec correctness

## OpenAPI 3.1.0 Resources

- [OpenAPI Specification](https://spec.openapis.org/oas/v3.1.0)
- [Swagger UI Documentation](https://swagger.io/tools/swagger-ui/)
- [ReDoc Documentation](https://redocly.com/docs/redoc/)

## Cloudflare Tunnel (Optional)

Securely expose your API documentation to the internet without opening ports or configuring firewalls.

### Quick Setup

```bash
# 1. Create Cloudflare Tunnel
#    Go to: https://one.dash.cloudflare.com/
#    Navigate to: Access → Tunnels → Create a tunnel
#    Name: api-docs
#    Copy the credentials JSON

# 2. Save tunnel credentials
mkdir -p .secrets
cat > .secrets/cf_tunnel_token << 'EOF'
{
  "AccountTag": "your-account-tag",
  "TunnelSecret": "your-tunnel-secret",
  "TunnelID": "your-tunnel-id"
}
EOF
chmod 600 .secrets/cf_tunnel_token

# 3. Configure tunnel
cp cloudflared-config.yaml.example cloudflared-config.yaml
# Edit cloudflared-config.yaml:
#   - Replace YOUR_TUNNEL_ID_HERE with your tunnel ID
#   - Replace api-docs.yourdomain.com with your domain

# 4. Configure DNS (Cloudflare Dashboard)
#    Add CNAME record:
#    Name: api-docs
#    Target: <tunnel-id>.cfargotunnel.com
#    Proxy: Enabled (orange cloud)

# 5. Start with cloudflare profile
docker compose --profile cloudflare up -d
```

### Features

- **No public IP needed**: Tunnel creates secure outbound connection
- **Automatic SSL/TLS**: Cloudflare handles certificates
- **DDoS protection**: Built-in Cloudflare security
- **Access control**: Optional authentication with Cloudflare Access
- **Free tier available**: Perfect for documentation hosting

### Adding Authentication

Protect your documentation with Cloudflare Access:

1. Go to: **Zero Trust → Access → Applications**
2. **Add Application**:
   - Name: API Documentation
   - Domain: api-docs.yourdomain.com
3. **Add Policy**:
   - Name: Allow Team
   - Action: Allow
   - Include: Emails ending in @yourcompany.com

Now users must authenticate before viewing documentation.

### Without Cloudflare Tunnel

If you don't need public access:

```bash
# Just run locally (default)
docker compose up

# Access at http://localhost:8080
```

## Tips

### Validation

Use online validators to check your OpenAPI spec:
- [Swagger Editor](https://editor.swagger.io/)
- [OpenAPI.Tools Validators](https://openapi.tools/#validators)

### CI/CD Integration

Consider adding OpenAPI validation to your CI pipeline:

```bash
# Using swagger-cli (npm install -g @apidevtools/swagger-cli)
swagger-cli validate docs/openapi/spec.yaml
```

## Troubleshooting

**Port 8080 already in use?**

Edit `compose.yaml` to use a different port:
```yaml
ports:
  - "8888:80"  # Use port 8888 instead
```

**YAML not loading?**

Ensure your YAML files are valid:
```bash
# Check YAML syntax
ruby -ryaml -e "YAML.load_file('spec.yaml')"
```

**Check nginx logs for errors:**
```bash
# Error logs
tail -f .srv/nginx/log/error.log

# Access logs
tail -f .srv/nginx/log/access.log
```

**CORS issues when calling API?**

Update your Rails API CORS configuration in `config/initializers/cors.rb` to allow requests from the documentation domain.

**Documentation not updating?**

The volume is mounted as read-only. If changes don't appear:
```bash
# Restart the container
docker compose restart

# Or rebuild if Dockerfile changed
docker compose up --build
```
