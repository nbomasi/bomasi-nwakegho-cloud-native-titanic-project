#!/bin/bash

set -euo pipefail

DEPLOYMENT_NAME="${1:-titanic-api}"
IMAGE_NAME="${2:-titanic-api:latest}"
NAMESPACE="${NAMESPACE:-titanic-api}"

echo "=========================================="
echo "Updating deployment image"
echo "Namespace: ${NAMESPACE}"
echo "=========================================="
echo ""

echo "Deployment: ${DEPLOYMENT_NAME}"
echo "New image: ${IMAGE_NAME}"
echo ""

echo "Current image:"
kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""
echo ""

echo "Updating image..."
kubectl set image deployment/${DEPLOYMENT_NAME} api=${IMAGE_NAME} -n ${NAMESPACE}

echo ""
echo "Waiting for rollout to complete..."
kubectl rollout status deployment/${DEPLOYMENT_NAME} -n ${NAMESPACE} --timeout=300s

echo ""
echo "Rollout completed. Current status:"
kubectl get pods -l app=titanic-api -n ${NAMESPACE}

echo ""
echo "=========================================="
echo "Image update completed successfully"
echo "=========================================="
