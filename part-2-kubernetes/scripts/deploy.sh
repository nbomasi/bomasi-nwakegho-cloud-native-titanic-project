#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"
NAMESPACE="${NAMESPACE:-titanic-api}"

echo "=========================================="
echo "Deploying Titanic API to Kubernetes"
echo "Namespace: ${NAMESPACE}"
echo "=========================================="

if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

echo ""
echo "Step 0: Creating namespace..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Step 1: Applying ConfigMap..."
kubectl apply -f "${MANIFESTS_DIR}/configmap.yaml" -n ${NAMESPACE}

echo ""
echo "Step 2: Applying Secret..."
echo "Warning: Ensure secret.yaml contains actual values before deployment"
kubectl apply -f "${MANIFESTS_DIR}/secret.yaml" -n ${NAMESPACE}

echo ""
echo "Step 3: Creating PersistentVolumeClaim..."
kubectl apply -f "${MANIFESTS_DIR}/pvc.yaml" -n ${NAMESPACE}

echo ""
echo "Step 4: Deploying Application and Database..."
kubectl apply -f "${MANIFESTS_DIR}/deployment.yaml" -n ${NAMESPACE}

echo ""
echo "Step 5: Creating Services..."
kubectl apply -f "${MANIFESTS_DIR}/service.yaml" -n ${NAMESPACE}

echo ""
echo "Step 6: Configuring Ingress..."
kubectl apply -f "${MANIFESTS_DIR}/ingress.yaml" -n ${NAMESPACE}

echo ""
echo "Step 7: Setting up Horizontal Pod Autoscaler..."
kubectl apply -f "${MANIFESTS_DIR}/hpa.yaml" -n ${NAMESPACE}

echo ""
echo "Step 8: Creating Pod Disruption Budget..."
kubectl apply -f "${MANIFESTS_DIR}/pdb.yaml" -n ${NAMESPACE}

echo ""
echo "Step 9: Applying Network Policies..."
kubectl apply -f "${MANIFESTS_DIR}/networkpolicy.yaml" -n ${NAMESPACE}

echo ""
echo "Step 10: Setting Resource Quotas..."
kubectl apply -f "${MANIFESTS_DIR}/resourcequota.yaml" -n ${NAMESPACE}

echo ""
echo "=========================================="
echo "Deployment completed successfully!"
echo "=========================================="
echo ""
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app=titanic-api \
    -n ${NAMESPACE} \
    --timeout=300s || true

echo ""
echo "Current deployment status:"
kubectl get pods -l app=titanic-api -n ${NAMESPACE}
kubectl get services -l app=titanic-api -n ${NAMESPACE}
kubectl get ingress -l app=titanic-api -n ${NAMESPACE}

echo ""
echo "To check detailed status, run: ./scripts/check-status.sh"
