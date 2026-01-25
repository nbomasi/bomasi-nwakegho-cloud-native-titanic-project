#!/bin/bash
set -e

# Manual staging deployment script for troubleshooting
# Replica count set to 1 for easier debugging

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root
cd "$PROJECT_ROOT"

NAMESPACE="titanic-api-staging"
RELEASE_NAME="titanic-api-staging"
IMAGE_REPO="456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CHART_PATH="./part-2-kubernetes/helm/titanic-api"

echo "🚀 Deploying to staging (manual troubleshooting mode)"
echo "   Working directory: $(pwd)"
echo "   Namespace: $NAMESPACE"
echo "   Release: $RELEASE_NAME"
echo "   Image: $IMAGE_REPO:$IMAGE_TAG"
echo "   Replicas: 1 (for troubleshooting)"
echo ""

# Verify chart path exists
if [ ! -d "$CHART_PATH" ]; then
    echo "❌ Error: Chart path not found: $CHART_PATH"
    echo "   Current directory: $(pwd)"
    echo "   Expected chart at: $CHART_PATH"
    exit 1
fi

# Check if kubectl is configured
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Error: kubectl is not configured or cluster is not accessible"
    exit 1
fi

# Check if ClusterSecretStore exists
echo "📋 Checking prerequisites..."
if kubectl get clustersecretstore aws-secrets-manager &>/dev/null; then
    READY=$(kubectl get clustersecretstore aws-secrets-manager -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    if [ "$READY" == "True" ]; then
        echo "✓ ClusterSecretStore is ready"
    else
        echo "⚠️  ClusterSecretStore exists but may not be ready"
    fi
else
    echo "⚠️  ClusterSecretStore not found. It will be created by Helm hooks."
fi

# Fix existing secret Helm ownership if it exists
echo ""
echo "🔧 Checking for existing secret..."
SECRET_NAME="titanic-api-staging-secrets"
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "   Existing secret found. Adding Helm ownership metadata..."
    kubectl label secret "$SECRET_NAME" -n "$NAMESPACE" \
        app.kubernetes.io/managed-by=Helm --overwrite || true
    kubectl annotate secret "$SECRET_NAME" -n "$NAMESPACE" \
        meta.helm.sh/release-name="$RELEASE_NAME" \
        meta.helm.sh/release-namespace="$NAMESPACE" \
        --overwrite || true
    echo "✓ Helm ownership metadata added"
else
    echo "   No existing secret found. ExternalSecret will create it."
fi

# Deploy with Helm
echo ""
echo "📦 Deploying with Helm..."
helm upgrade --install "$RELEASE_NAME" \
    "$CHART_PATH" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --set image.repository="$IMAGE_REPO" \
    --set image.tag="$IMAGE_TAG" \
    --set image.pullPolicy=Always \
    --set namespace="$NAMESPACE" \
    --set config.flaskEnv=staging \
    --set replicaCount=1 \
    --set autoscaling.enabled=false \
    --set ingress.enabled=true \
    --set ingress.hosts[0].host=titanic-api.iyere.site \
    --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
    --set ingress.hosts[0].paths[0].path=/ \
    --set ingress.hosts[0].paths[0].pathType=Prefix \
    --set ingress.hosts[0].paths[1].path=/health \
    --set ingress.hosts[0].paths[1].pathType=Exact \
    --set ingress.hosts[0].paths[2].path=/people \
    --set ingress.hosts[0].paths[2].pathType=Prefix \
    --set podDisruptionBudget.enabled=true \
    --set podDisruptionBudget.minAvailable=1 \
    --set database.enabled=false \
    --set externalSecrets.externalSecret.enabled=true \
    --set externalSecrets.externalSecret.secretName=titanic-api-prod-rds-credentials \
    --set externalSecrets.externalSecret.targetSecretName=titanic-api-staging-secrets \
    --set externalSecrets.secretStore.enabled=true \
    --wait \
    --timeout 15m

echo ""
echo "✅ Helm deployment completed"
echo ""

# Wait for ExternalSecret to sync
echo "⏳ Waiting for ExternalSecret to sync..."
for i in {1..60}; do
    if kubectl get externalsecret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
        SYNC_STATUS=$(kubectl get externalsecret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [ "$SYNC_STATUS" == "True" ]; then
            echo "✓ ExternalSecret synced successfully"
            break
        fi
        echo "   Waiting for ExternalSecret to sync... (attempt $i/60) - Status: $SYNC_STATUS"
        if [ $i -le 10 ]; then
            kubectl describe externalsecret "$SECRET_NAME" -n "$NAMESPACE" | tail -10 || true
        fi
    else
        echo "   ExternalSecret not found yet... (attempt $i/60)"
    fi
    sleep 5
done

# Check deployment status
echo ""
echo "📊 Deployment Status:"
kubectl get deployment -n "$NAMESPACE" "$RELEASE_NAME" || echo "Deployment not found"

echo ""
echo "📦 Pod Status:"
kubectl get pods -n "$NAMESPACE" -l app=titanic-api

echo ""
echo "🔍 To troubleshoot:"
echo "   kubectl logs -n $NAMESPACE -l app=titanic-api --tail=100"
echo "   kubectl describe pod -n $NAMESPACE -l app=titanic-api"
echo "   kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -20"
echo ""
echo "🌐 To check ingress:"
echo "   kubectl get ingress -n $NAMESPACE"
echo ""
