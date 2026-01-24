#!/bin/bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-titanic-api}"

echo "=========================================="
echo "Titanic API Deployment Status"
echo "Namespace: ${NAMESPACE}"
echo "=========================================="
echo ""

echo "--- Pods ---"
kubectl get pods -l app=titanic-api -n ${NAMESPACE} -o wide
echo ""

echo "--- Services ---"
kubectl get services -l app=titanic-api -n ${NAMESPACE}
echo ""

echo "--- Ingress ---"
kubectl get ingress -l app=titanic-api -n ${NAMESPACE}
echo ""

echo "--- Horizontal Pod Autoscaler ---"
kubectl get hpa -l app=titanic-api -n ${NAMESPACE}
echo ""

echo "--- Pod Disruption Budget ---"
kubectl get pdb -l app=titanic-api -n ${NAMESPACE}
echo ""

echo "--- Network Policies ---"
kubectl get networkpolicies -l app=titanic-api -n ${NAMESPACE}
echo ""

echo "--- Resource Quotas ---"
kubectl get resourcequota -l app=titanic-api -n ${NAMESPACE}
kubectl get limitrange -l app=titanic-api -n ${NAMESPACE}
echo ""

echo "--- Persistent Volume Claims ---"
kubectl get pvc -l app=titanic-api -n ${NAMESPACE}
echo ""

echo "--- Deployment Status ---"
kubectl rollout status deployment/titanic-api -n ${NAMESPACE} || true
kubectl rollout status deployment/titanic-db -n ${NAMESPACE} || true
echo ""

echo "--- Recent Events ---"
kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp' | tail -10
echo ""

echo "=========================================="
echo "Status check completed"
echo "=========================================="
