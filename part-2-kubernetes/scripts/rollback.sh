#!/bin/bash

set -euo pipefail

DEPLOYMENT_NAME="${1:-titanic-api}"
NAMESPACE="${NAMESPACE:-titanic-api}"

echo "=========================================="
echo "Rolling back deployment: ${DEPLOYMENT_NAME}"
echo "Namespace: ${NAMESPACE}"
echo "=========================================="
echo ""

echo "Current deployment history:"
kubectl rollout history deployment/${DEPLOYMENT_NAME} -n ${NAMESPACE}
echo ""

if [ -n "${2:-}" ]; then
    REVISION="${2}"
    echo "Rolling back to revision ${REVISION}..."
    kubectl rollout undo deployment/${DEPLOYMENT_NAME} --to-revision=${REVISION} -n ${NAMESPACE}
else
    echo "Rolling back to previous revision..."
    kubectl rollout undo deployment/${DEPLOYMENT_NAME} -n ${NAMESPACE}
fi

echo ""
echo "Waiting for rollback to complete..."
kubectl rollout status deployment/${DEPLOYMENT_NAME} -n ${NAMESPACE} --timeout=300s

echo ""
echo "Rollback completed. Current status:"
kubectl get pods -l app=titanic-api -n ${NAMESPACE}

echo ""
echo "=========================================="
echo "Rollback completed successfully"
echo "=========================================="
