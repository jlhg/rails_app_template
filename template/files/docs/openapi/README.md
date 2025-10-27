# OpenAPI Documentation

This directory contains the OpenAPI specification for your API,
along with a standalone documentation service using Docker.

## Directory Structure

```
/
├── Dockerfile              # nginx:1.29-alpine with embedded configuration
├── compose.yaml            # Docker Compose configuration
├── .dockerignore           # Files excluded from Docker image
├── .gitignore              # Files excluded from git
├── spec.yaml               # Main OpenAPI specification file
├── index.html              # Documentation entry page
├── swagger.html            # Swagger UI interface
├── redoc.html              # ReDoc interface
├── attributes/             # Atomic attribute definitions (like Rails model fields)
│   ├── common.yaml        # Shared attributes: id, created_at, updated_at
│   └── resource.yaml      # Resource-specific attributes: name, description, status
├── parameters/             # Reusable parameter definitions
│   ├── id.yaml            # UUID path parameter
│   └── pagination.yaml    # Pagination query parameters
├── request_bodies/         # Reusable request body definitions
│   └── resource.yaml      # Resource creation/update bodies
├── responses/              # Reusable response definitions
│   ├── success.yaml       # Success response formats
│   ├── error.yaml         # Error response formats
│   └── not_found.yaml     # 404 response
└── schemas/                # Data model schemas (like Rails serializers)
    ├── resource.yaml      # Example resource model (combines attributes)
    ├── error.yaml         # Error response schema
    └── metadata.yaml      # Pagination metadata schema
```

## Resources

- [OpenAPI Specification](https://spec.openapis.org/oas/v3.1.0)
- [Swagger UI Documentation](https://swagger.io/tools/swagger-ui/)
- [ReDoc Documentation](https://redocly.com/docs/redoc/)
