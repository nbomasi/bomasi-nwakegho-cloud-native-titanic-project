#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/../manifests"
NAMESPACE="${NAMESPACE:-titanic-api}"

echo "=========================================="
echo "Tearing down Titanic API deployment"
echo "Namespace: ${NAMESPACE}"
echo "=========================================="
echo ""

read -p "Are you sure you want to delete all resources in namespace '${NAMESPACE}'? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Deleting resources..."

echo "Removing Resource Quotas..."
kubectl delete -f "${MANIFESTS_DIR}/resourcequota.yaml" --ignore-not-found=true -n ${NAMESPACE}

echo "Removing Network Policies..."
kubectl delete -f "${MANIFESTS_DIR}/networkpolicy.yaml" --ignore-not-found=true -n ${NAMESPACE}

echo "Removing Pod Disruption Budget..."
kubectl delete -f "${MANIFESTS_DIR}/pdb.yaml" --ignore-not-found=true -n ${NAMESPACE}

echo "Removing Horizontal Pod Autoscaler..."
kubectl delete -f "${MANIFESTS_DIR}/hpa.yaml" --ignore-not-found=true -n ${NAMESPACE}

echo "Removing Ingress..."
kubectl delete -f "${MANIFESTS_DIR}/ingress.yaml" --ignore-not-found=true -n ${NAMESPACE}

echo "Removing Services..."
kubectl delete -f "${MANIFESTS_DIR}/service.yaml" --ignore-not-found=true -n ${NAMESPACE}

echo "Removing Deployments..."
kubectl delete -f "${MANIFESTS_DIR}/deployment.yaml" --ignore-not-found=true -n ${NAMESPACE}

echo "Removing PersistentVolumeClaim..."
read -p "Delete PersistentVolumeClaim? This will delete all database data! (yes/no): " delete_pvc
if [ "$delete_pvc" = "yes" ]; then
    kubectl delete -f "${MANIFESTS_DIR}/pvc.yaml" --ignore-not-found=true -n ${NAMESPACE}
    echo "PersistentVolumeClaim deleted."
else
    echo "PersistentVolumeClaim preserved."
fi

echo "Removing Secrets..."
kubectl delete -f "${MANIFESTS_DIR}/secret.yaml" --ignore-not-found=true -n ${NAMESPACE}

echo "Removing ConfigMap..."
kubectl delete -f "${MANIFESTS_DIR}/configmap.yaml" --ignore-not-found=true -n ${NAMESPACE}

echo ""
read -p "Delete namespace '${NAMESPACE}'? (yes/no): " delete_ns
if [ "$delete_ns" = "yes" ]; then
    echo "Deleting namespace..."
    kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
    echo "Namespace deleted."
else
    echo "Namespace preserved."
fi

echo ""
echo "Waiting for resources to be deleted..."
sleep 5

echo ""
echo "Remaining resources:"
kubectl get all -l app=titanic-api -n ${NAMESPACE} 2>/dev/null || echo "No resources found or namespace does not exist."

echo ""
echo "=========================================="
echo "Teardown completed"
echo "=========================================="
