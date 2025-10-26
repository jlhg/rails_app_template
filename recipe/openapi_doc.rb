# OpenAPI Documentation Setup
#
# This recipe copies the complete OpenAPI documentation structure to your project.
# The documentation service runs independently using Docker and nginx.
#
# Directory structure:
#   docs/openapi/           - OpenAPI documentation root
#   ├── Dockerfile          - nginx:alpine with embedded configuration
#   ├── compose.yaml        - Standalone Docker Compose service
#   ├── spec.yaml           - Main OpenAPI 3.1.0 specification
#   ├── *.html              - Documentation interfaces (Swagger UI, ReDoc)
#   ├── parameters/         - Reusable parameter definitions
#   ├── request_bodies/     - Reusable request body definitions
#   ├── responses/          - Reusable response definitions
#   └── schemas/            - Data model schemas
#
# Usage:
#   cd docs/openapi
#   docker compose up
#   Access: http://localhost:8080

# Copy the entire OpenAPI documentation structure
directory "docs/openapi", "docs/openapi"

say_status :info, "OpenAPI documentation template installed in docs/openapi/", :green
say_status :usage, "Run 'cd docs/openapi && docker compose up' to start the documentation service", :yellow
say_status :access, "Documentation will be available at http://localhost:8080", :yellow
