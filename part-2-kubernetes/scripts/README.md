# Deployment Scripts

This directory contains deployment and management scripts for the Titanic API Kubernetes deployment.

## Scripts Overview

### `deploy.sh`
Deploys all Kubernetes manifests in the correct order.

**Usage:**
```bash
./scripts/deploy.sh
```

**What it does:**
- Applies all manifests in sequence (ConfigMap, Secret, PVC, Deployments, Services, etc.)
- Waits for pods to be ready
- Shows deployment status

### `check-status.sh`
Displays comprehensive status of all deployed resources.

**Usage:**
```bash
./scripts/check-status.sh
```

**What it shows:**
- Pod status
- Services
- Ingress
- HPA status
- PDB status
- Network policies
- Resource quotas
- PVC status
- Recent events

### `rollback.sh`
Rolls back a deployment to a previous revision.

**Usage:**
```bash
# Rollback to previous revision
./scripts/rollback.sh titanic-api

# Rollback to specific revision
./scripts/rollback.sh titanic-api 2
```

**What it does:**
- Shows deployment history
- Rolls back to previous or specified revision
- Waits for rollback to complete
- Shows current status

### `update-secrets.sh`
Updates Kubernetes secrets from environment variables.

**Usage:**
```bash
export DATABASE_URL='postgresql+psycopg2://user:pass@titanic-db:5432/titanic_db'
export POSTGRES_USER='titanic_user'
export POSTGRES_PASSWORD='secure_password'
export JWT_SECRET_KEY='secure_jwt_key'

./scripts/update-secrets.sh
```

**What it does:**
- Creates/updates secrets from environment variables
- Restarts deployments to pick up new secrets
- Waits for deployments to be ready

### `update-image.sh`
Updates the container image for a deployment.

**Usage:**
```bash
# Update application image
./scripts/update-image.sh titanic-api titanic-api:v1.1.0

# Update with default deployment name
./scripts/update-image.sh titanic-api titanic-api:latest
```

**What it does:**
- Updates deployment image
- Triggers rolling update
- Waits for rollout to complete
- Shows pod status

### `teardown.sh`
Removes all deployed resources (with confirmation).

**Usage:**
```bash
./scripts/teardown.sh
```

**What it does:**
- Prompts for confirmation
- Deletes all resources in reverse order
- Optionally deletes PVC (with separate confirmation)
- Shows remaining resources

### `view-logs.sh`
Views logs from application or database pods.

**Usage:**
```bash
# View application logs
./scripts/view-logs.sh api

# View database logs
./scripts/view-logs.sh db

# Follow application logs
./scripts/view-logs.sh api -f

# View all logs
./scripts/view-logs.sh all
```

**What it does:**
- Displays logs from specified component
- Supports following logs in real-time
- Shows last 100 lines by default

## Prerequisites

- `kubectl` installed and configured
- Access to target Kubernetes cluster
- Scripts must be executable: `chmod +x scripts/*.sh`

## Common Workflows

### Initial Deployment
```bash
# 1. Update secrets in secret.yaml or use update-secrets.sh
# 2. Deploy everything
./scripts/deploy.sh

# 3. Check status
./scripts/check-status.sh
```

### Update Application
```bash
# 1. Build new image
docker build -t titanic-api:v1.1.0 -f part-1-containerization/Dockerfile .

# 2. Update deployment
./scripts/update-image.sh titanic-api titanic-api:v1.1.0

# 3. Monitor rollout
./scripts/check-status.sh
```

### Update Secrets
```bash
# 1. Set environment variables
export DATABASE_URL='...'
export POSTGRES_USER='...'
export POSTGRES_PASSWORD='...'
export JWT_SECRET_KEY='...'

# 2. Update secrets
./scripts/update-secrets.sh
```

### Rollback Deployment
```bash
# 1. Check history
kubectl rollout history deployment/titanic-api

# 2. Rollback
./scripts/rollback.sh titanic-api
```

### Troubleshooting
```bash
# 1. Check status
./scripts/check-status.sh

# 2. View logs
./scripts/view-logs.sh api -f
./scripts/view-logs.sh db -f

# 3. Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Complete Removal
```bash
./scripts/teardown.sh
```

## Error Handling

All scripts use `set -euo pipefail` for error handling:
- Exits on any command failure
- Exits on undefined variables
- Exits on pipe failures

Scripts include appropriate error messages and validation.

## Security Notes

- Secrets should never be committed to version control
- Use `update-secrets.sh` with environment variables for production
- Consider using external secret management tools for production
- Review and update secret values before deployment
