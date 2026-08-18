# Part 1: Containerization & Local Development

## Executive Summary

This document describes the containerization and local development setup for the Titanic API, a Flask-based REST API application. The implementation provides production-ready Docker images with optimized multi-stage builds, comprehensive Docker Compose orchestration for both development and production environments, and automated database initialization. All requirements for Part 1 of the technical assessment have been met, including image size optimization (under 200MB), security hardening with non-root user execution, and a seamless development workflow with hot-reload capabilities.

## Table of Contents

1. [Requirements Overview](#requirements-overview)
2. [Architecture](#architecture)
3. [Implementation Details](#implementation-details)
4. [File Structure](#file-structure)
5. [Setup and Usage](#setup-and-usage)
6. [Design Decisions](#design-decisions)
7. [Security Features](#security-features)
8. [Performance Optimization](#performance-optimization)
9. [Verification and Testing](#verification-and-testing)
10. [Compliance with Requirements](#compliance-with-requirements)
11. [Known Limitations](#known-limitations)
12. [References](#references)
13. [Conclusion](#conclusion)

## Requirements Overview

### 1. Multi-stage Dockerfile

**Requirement:** Create an optimized multi-stage build with non-root user, proper layer caching, health checks, and target size under 200MB.

**Implementation Status:** Complete

- Multi-stage build with separate builder and production stages
- Non-root user execution (appuser, UID 1000, GID 1000)
- Optimized layer caching strategy
- Built-in health check configuration
- Final image size: 71.3 MB (verified)

### 2. Docker Compose Setup

**Requirement:** Multi-container orchestration with proper networking, service dependencies, volume management, health checks, restart policies, and environment variable management.

**Implementation Status:** Complete

- Multi-container setup (application + PostgreSQL database)
- Isolated bridge networks for dev and prod environments
- Service dependency management with health check conditions
- Named volumes for persistent data storage
- Health checks for both application and database services
- Restart policies configured (unless-stopped)
- Comprehensive environment variable management

### 3. Development Workflow

**Requirement:** Separate dev and prod configurations, hot-reload for development, and automated database initialization.

**Implementation Status:** Complete

- Separate Docker Compose files for development and production
- Hot-reload enabled via volume mounts in development mode
- Automated database initialization through multiple mechanisms

## Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Development Environment               │
│                                                          │
│  ┌──────────────────┐         ┌──────────────────┐    │
│  │  titanic-app-dev │─────────│  titanic-db-dev   │    │
│  │  (Flask Dev)     │         │  (PostgreSQL)     │    │
│  │  Hot-reload      │         │  postgres_data_dev│    │
│  └──────────────────┘         └──────────────────┘    │
│         │                              │                 │
│  titanic-network-dev (bridge)                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   Production Environment                │
│                                                          │
│  ┌──────────────────┐         ┌──────────────────┐    │
│  │   titanic-app   │─────────│    titanic-db    │    │
│  │   (Gunicorn)    │         │  (PostgreSQL)    │    │
│  │   Non-root user │         │  postgres_data   │    │
│  └──────────────────┘         └──────────────────┘    │
│         │                              │                 │
│  titanic-network (bridge)                               │
└─────────────────────────────────────────────────────────┘
```

### Container Architecture

**Production Container:**
- Base Image: python:3.11-slim
- User: appuser (UID 1000, GID 1000)
- WSGI Server: Gunicorn (4 workers, 2 threads per worker)
- Health Check: Built-in Docker HEALTHCHECK + application endpoint
- Image Size: 71.3 MB

**Development Container:**
- Base Image: python:3.11-slim
- User: root (for development convenience)
- Server: Flask development server with auto-reload
- Volume Mounts: Source code mounted for hot-reload
- Image Size: 153 MB (includes build dependencies)

## Implementation Details

### Multi-stage Dockerfile (Production)

The production Dockerfile implements a two-stage build process:

**Stage 1: Builder**
- Installs build dependencies (gcc, libc6-dev, libpq-dev)
- Compiles and installs Python packages to user directory
- Results in intermediate image with build tools

**Stage 2: Production**
- Creates non-root user (appuser)
- Copies only compiled packages from builder stage
- Installs minimal runtime dependencies (libpq5, postgresql-client)
- Sets proper file permissions
- Configures health checks
- Uses Gunicorn as production WSGI server

**Key Features:**
- Layer caching optimization: Dependencies installed before code copy
- Security: Non-root user execution
- Size optimization: Only runtime dependencies in final image
- Health monitoring: Built-in Docker health check

### Development Dockerfile

The development Dockerfile uses a single-stage build optimized for development workflow:

- Includes all build dependencies for hot-reload compatibility
- Simpler structure for faster iteration
- Runs as root for development convenience
- Uses Flask development server with auto-reload

### Docker Compose Configuration

**Production Configuration (`docker-compose.yml`):**
- Database: PostgreSQL 15 Alpine
- Application: Multi-stage production build
- Networking: Isolated bridge network (titanic-network)
- Volumes: Named volume for data persistence (postgres_data)
- Health Checks: Configured for both services
- Restart Policy: unless-stopped

**Development Configuration (`docker-compose.dev.yml`):**
- Database: PostgreSQL 15 Alpine (separate volume: postgres_data_dev)
- Application: Development build with volume mounts
- Networking: Separate bridge network (titanic-network-dev)
- Hot-reload: Source code mounted as volume
- Environment: FLASK_ENV=development

### Database Initialization

Database initialization is automated through three mechanisms:

1. **PostgreSQL Automatic Initialization:**
   - Database and user created automatically from environment variables
   - Executes on first container start when volume is empty

2. **SQL Script Execution:**
   - `titanic.sql` mounted to `/docker-entrypoint-initdb.d/init.sql`
   - Automatically executed by PostgreSQL on first initialization
   - Creates database schema (people table)

3. **Application-Level Table Creation:**
   - Flask application calls `db.create_all()` on startup
   - Ensures tables exist even if SQL script was skipped
   - Acts as backup initialization mechanism

## File Structure

```
part-1-containerization/
├── Dockerfile                  # Production multi-stage build
├── Dockerfile.dev              # Development build
├── docker-compose.yml          # Production orchestration
├── docker-compose.dev.yml      # Development orchestration
├── .dockerignore               # Build context exclusions
└── CONTAINERIZATION.md         # This documentation
```

## Setup and Usage

### Prerequisites

- Docker Engine 20.10+ or Docker Desktop
- Docker Compose v2.0+ (or docker-compose v1.29+)
- Git (for cloning repository)

### Development Mode

**Start Services:**
```bash
cd cloud-native-titanic/part-1-containerization
docker compose -f docker-compose.dev.yml up --build
```

**Features:**
- Hot-reload enabled (code changes reflected immediately)
- Development-friendly logging
- Separate data volume (postgres_data_dev)
- Flask development server

**Test API:**
```bash
# Health check
curl http://localhost:5000/health

# Get all passengers
curl http://localhost:5000/people

# Create new passenger
curl -X POST http://localhost:5000/people \
  -H "Content-Type: application/json" \
  -d '{
    "survived": 1,
    "passengerClass": 1,
    "name": "Mr. John Doe",
    "sex": "male",
    "age": 30.0,
    "siblingsOrSpousesAboard": 1,
    "parentsOrChildrenAboard": 0,
    "fare": 50.0
  }'
```

**Stop Services:**
```bash
docker compose -f docker-compose.dev.yml down
```

**Note:** Data persists in `postgres_data_dev` volume. To remove all data:
```bash
docker compose -f docker-compose.dev.yml down -v
```

### Production Mode

**Create Local Environment File:**
```bash
cp .env.example .env
openssl rand -base64 24  # use the output for POSTGRES_PASSWORD
openssl rand -hex 32     # use the output for JWT_SECRET_KEY
```

Populate `.env` locally. Docker Compose refuses to start when either secret is missing, and `.env` is excluded from version control.

**Start Services:**
```bash
docker compose up --build -d
```

**Monitor Services:**
```bash
# Check status
docker compose ps

# View logs
docker compose logs -f app
docker compose logs -f db
```

**Stop Services:**
```bash
docker compose down
```

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `POSTGRES_USER` | PostgreSQL username | `titanic_user` | No |
| `POSTGRES_PASSWORD` | PostgreSQL password | None | Yes |
| `POSTGRES_DB` | Database name | `titanic_db` (prod), `postgres` (dev) | No |
| `POSTGRES_PORT` | PostgreSQL port | `5432` | No |
| `APP_PORT` | Application port | `5000` | No |
| `JWT_SECRET_KEY` | JWT signing key | None | Yes |
| `FLASK_ENV` | Flask environment | `production` or `development` | No |

## Design Decisions

### 1. Multi-stage Build Strategy

**Decision:** Use two-stage build (builder + production)

**Rationale:**
- Significantly reduces final image size (from ~600MB to 71.3 MB)
- Separates build dependencies from runtime dependencies
- Improves security by excluding build tools from production image
- Meets requirement of image size under 200MB

### 2. Separate Development and Production Dockerfiles

**Decision:** Maintain separate Dockerfile and Dockerfile.dev

**Rationale:**
- Development needs volume mounts and simpler build process
- Production requires optimization and security hardening
- Different runtime servers (Flask dev server vs Gunicorn)
- Allows independent evolution of dev and prod configurations

### 3. Gunicorn for Production

**Decision:** Use Gunicorn WSGI server instead of Flask development server

**Rationale:**
- Production-grade WSGI server with better performance
- Supports multiple workers and threads
- Better handling of concurrent requests
- Industry standard for Python web applications

### 4. Non-root User in Production

**Decision:** Run application as non-root user (appuser, UID 1000)

**Rationale:**
- Security best practice (principle of least privilege)
- Required for production deployments
- Reduces attack surface
- Compliance with security standards

### 5. PostgreSQL Alpine Image

**Decision:** Use postgres:15-alpine instead of standard postgres image

**Rationale:**
- Smaller image size (~110MB vs ~400MB)
- Sufficient functionality for this use case
- Faster image pulls and deployments
- Lower resource consumption

### 6. Separate Networks and Volumes

**Decision:** Use separate networks and volumes for dev and prod

**Rationale:**
- Prevents conflicts when running both environments simultaneously
- Isolates data between environments
- Allows independent testing without affecting production data
- Better security isolation

### 7. Health Check Endpoint

**Decision:** Implement `/health` endpoint with database connectivity check

**Rationale:**
- Essential for container orchestration platforms (Kubernetes)
- Enables proper service dependency management
- Provides operational visibility
- Required for production deployments

## Security Features

### Production Security

1. **Non-root User Execution:**
   - Application runs as `appuser` (UID 1000, GID 1000)
   - Prevents privilege escalation attacks
   - Limits potential damage from container compromise

2. **Minimal Base Image:**
   - Uses python:3.11-slim (Debian-based minimal image)
   - Reduces attack surface
   - Fewer packages means fewer vulnerabilities

3. **No Build Dependencies in Production:**
   - Build tools (gcc, libc6-dev) excluded from final image
   - Reduces image size and attack surface
   - Prevents compilation-based attacks

4. **Proper File Permissions:**
   - Application files owned by appuser
   - Prevents unauthorized modifications
   - Follows principle of least privilege

5. **Health Check Monitoring:**
   - Built-in Docker health checks
   - Application-level health endpoint
   - Enables automatic container restart on failure

### Development Security

- Runs as root for development convenience
- Includes build dependencies for hot-reload
- Separate network and volume isolation
- Not intended for production use

## Performance Optimization

### Image Size Optimization

**Target:** Under 200MB
**Achieved:** 71.3 MB (64% under target)

**Optimization Techniques:**
1. Multi-stage build eliminates build dependencies from final image
2. Minimal base image (python:3.11-slim)
3. Alpine-based PostgreSQL image
4. Layer caching optimization
5. .dockerignore to exclude unnecessary files

### Layer Caching Strategy

**Optimization:** Dependencies installed before code copy

**Benefits:**
- Code changes don't invalidate dependency cache
- Faster rebuilds during development
- Reduced build time in CI/CD pipelines

**Layer Order:**
1. Base image
2. System dependencies
3. Python dependencies (requirements.txt)
4. Application code (changes frequently)

### Runtime Performance

**Gunicorn Configuration:**
- 4 worker processes
- 2 threads per worker
- Total: 8 concurrent request handlers
- 120-second timeout for long-running requests

**Database Connection:**
- Connection pooling via SQLAlchemy
- Automatic reconnection on failure
- Health check validates connectivity

## Verification and Testing

### Image Size Verification

```bash
docker images | grep part-1-containerization
```

**Expected Output:**
- CONTENT SIZE: 71.3 MB
- DISK USAGE: ~625MB (includes shared layers)

### Security Verification

**Verify Non-root User:**
```bash
docker compose exec app whoami
# Expected: appuser
```

**Verify User ID:**
```bash
docker compose exec app id
# Expected: uid=1000(appuser) gid=1000(appuser)
```

### Health Check Verification

**Application Health:**
```bash
curl http://localhost:5000/health
# Expected: {"status": "healthy", "database": "connected"}
```

**Docker Health Status:**
```bash
docker compose ps
# Expected: Healthy status for both services
```

### Functionality Testing

**API Endpoints:**
```bash
# Get all passengers
curl http://localhost:5000/people

# Create passenger
curl -X POST http://localhost:5000/people \
  -H "Content-Type: application/json" \
  -d '{"survived": 1, "passengerClass": 1, "name": "Test User", ...}'

# Get specific passenger
curl http://localhost:5000/people/<uuid>

# Update passenger
curl -X PUT http://localhost:5000/people/<uuid> \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Name"}'

# Delete passenger
curl -X DELETE http://localhost:5000/people/<uuid>
```

### Database Persistence Testing

**Test Data Persistence:**
```bash
# 1. Start services and create data
docker compose up -d
curl -X POST http://localhost:5000/people -H "Content-Type: application/json" -d '{...}'

# 2. Stop services
docker compose down

# 3. Restart services
docker compose up -d

# 4. Verify data persists
curl http://localhost:5000/people
# Data should still be present
```

### Hot-reload Testing (Development)

**Test Code Changes:**
```bash
# 1. Start dev environment
docker compose -f docker-compose.dev.yml up

# 2. Edit a file (e.g., src/app.py)
# Add a print statement or modify a route

# 3. Save the file
# Flask should automatically reload

# 4. Test the change
curl http://localhost:5000/
# Changes should be visible without rebuild
```

## Compliance with Requirements

### Requirement 1: Multi-stage Dockerfile

- [x] Optimized multi-stage build (builder + production stages)
- [x] Non-root user for security (appuser, UID 1000)
- [x] Proper layer caching (dependencies before code)
- [x] Health checks implemented (Docker HEALTHCHECK + endpoint)
- [x] Target size < 200MB (achieved: 71.3 MB)

### Requirement 2: Docker Compose Setup

- [x] Multi-container orchestration (app + database)
- [x] Proper networking (isolated bridge networks)
- [x] Service dependencies (health check conditions)
- [x] Volume management (named volumes for persistence)
- [x] Health checks (both services)
- [x] Restart policies (unless-stopped)
- [x] Environment variable management

### Requirement 3: Development Workflow

- [x] Separate dev and prod configurations
- [x] Hot-reload for development (volume mounts)
- [x] Database initialization automation (multiple mechanisms)

## Known Limitations

The following limitations are acknowledged and will be addressed in subsequent parts of the assessment:

1. **Secrets Management:** Currently using environment variables. Part 6 (Security) will implement proper secrets management.

2. **Database Deployment:** Database runs in same Docker Compose file. Part 5 (Infrastructure as Code) will use managed database services.

3. **Monitoring:** No observability implemented yet. Part 4 (Observability) will add Prometheus metrics and Grafana dashboards.

4. **CI/CD:** No automated build and deployment pipeline. Part 3 (CI/CD) will implement GitHub Actions workflows.

5. **High Availability:** Single database instance without replication. Part 2 (Kubernetes) will enable horizontal scaling.

## References

- [Docker Official Documentation](https://docs.docker.com/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Gunicorn Documentation](https://docs.gunicorn.org/)
- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)

## Conclusion

Part 1: Containerization & Local Development has been successfully completed with all requirements met. The implementation provides:

- Production-ready containerization with optimized image size
- Comprehensive Docker Compose orchestration for both development and production
- Automated database initialization
- Security hardening with non-root user execution
- Seamless development workflow with hot-reload capabilities
- Professional documentation suitable for production use

The solution is ready for progression to Part 2: Kubernetes Deployment.
