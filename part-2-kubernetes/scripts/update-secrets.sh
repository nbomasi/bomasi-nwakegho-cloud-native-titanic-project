#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"

NAMESPACE="${NAMESPACE:-titanic-api}"

echo "=========================================="
echo "Updating Kubernetes Secrets"
echo "Namespace: ${NAMESPACE}"
echo "=========================================="
echo ""

if [ -z "${DATABASE_URL:-}" ] || [ -z "${POSTGRES_USER:-}" ] || [ -z "${POSTGRES_PASSWORD:-}" ] || [ -z "${JWT_SECRET_KEY:-}" ]; then
    echo "Error: Required environment variables not set"
    echo ""
    echo "Please set the following environment variables:"
    echo "  export DATABASE_URL='postgresql+psycopg2://user:pass@titanic-db:5432/titanic_db'"
    echo "  export POSTGRES_USER='titanic_user'"
    echo "  export POSTGRES_PASSWORD='secure_password'"
    echo "  export JWT_SECRET_KEY='secure_jwt_key'"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "Creating/updating secret from environment variables..."
kubectl create secret generic titanic-secrets \
    --from-literal=database-url="${DATABASE_URL}" \
    --from-literal=postgres-user="${POSTGRES_USER}" \
    --from-literal=postgres-password="${POSTGRES_PASSWORD}" \
    --from-literal=jwt-secret-key="${JWT_SECRET_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f - -n ${NAMESPACE}

echo ""
echo "Secret updated successfully!"
echo ""
echo "Restarting deployments to pick up new secrets..."
kubectl rollout restart deployment/titanic-api -n ${NAMESPACE}
kubectl rollout restart deployment/titanic-db -n ${NAMESPACE}

echo ""
echo "Waiting for deployments to be ready..."
kubectl rollout status deployment/titanic-api -n ${NAMESPACE} --timeout=300s
kubectl rollout status deployment/titanic-db -n ${NAMESPACE} --timeout=300s

echo ""
echo "=========================================="
echo "Secrets updated and deployments restarted"
echo "=========================================="
