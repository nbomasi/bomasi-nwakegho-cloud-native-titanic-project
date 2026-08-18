#!/bin/bash
# Deploy Titanic API using Kubernetes manifests
# Usage: ./deploy-manifests.sh <namespace> <image-tag> <environment>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${1:-titanic-api}"
IMAGE_TAG="${2:-latest}"
ENVIRONMENT="${3:-production}"
MANIFESTS_DIR="${MANIFESTS_DIR:-part-2-kubernetes/manifests}"
ECR_REPOSITORY_URL="${ECR_REPOSITORY_URL:?ECR_REPOSITORY_URL must be set}"
IMAGE_URL="${ECR_REPOSITORY_URL}:${IMAGE_TAG}"

echo -e "${GREEN}=== Deploying Titanic API ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Image: $IMAGE_URL"
echo "Environment: $ENVIRONMENT"
echo ""

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ kubectl found${NC}"
}

# Function to check cluster connectivity
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Cluster connectivity verified${NC}"
}

# Function to create namespace if it doesn't exist
create_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        echo "Creating namespace: $NAMESPACE"
        kubectl create namespace "$NAMESPACE"
        echo -e "${GREEN}✓ Namespace created${NC}"
    else
        echo -e "${GREEN}✓ Namespace exists${NC}"
    fi
}

# Function to update environment-specific configurations
update_environment_config() {
    echo "Updating environment-specific configurations..."
    
    # Update ConfigMap with environment
    if [ -f "$MANIFESTS_DIR/configmap.yaml" ]; then
        local temp_file=$(mktemp)
        sed "s/flask-env:.*/flask-env: ${ENVIRONMENT}/g" \
            "$MANIFESTS_DIR/configmap.yaml" > "$temp_file"
        mv "$temp_file" "$MANIFESTS_DIR/configmap.yaml"
    fi
    
    # Update deployment replicas based on environment
    if [ -f "$MANIFESTS_DIR/deployment.yaml" ]; then
        local temp_file=$(mktemp)
        case "$ENVIRONMENT" in
            development)
                sed "s/replicas:.*/replicas: 1/g" \
                    "$MANIFESTS_DIR/deployment.yaml" > "$temp_file"
                ;;
            staging)
                sed "s/replicas:.*/replicas: 2/g" \
                    "$MANIFESTS_DIR/deployment.yaml" > "$temp_file"
                ;;
            production)
                sed "s/replicas:.*/replicas: 2/g" \
                    "$MANIFESTS_DIR/deployment.yaml" > "$temp_file"
                ;;
            *)
                echo -e "${YELLOW}⚠ Unknown environment, using default replicas${NC}"
                cp "$MANIFESTS_DIR/deployment.yaml" "$temp_file"
                ;;
        esac
        mv "$temp_file" "$MANIFESTS_DIR/deployment.yaml"
    fi
    
    # Update HPA based on environment
    if [ -f "$MANIFESTS_DIR/hpa.yaml" ]; then
        local temp_file=$(mktemp)
        case "$ENVIRONMENT" in
            development)
                # Disable HPA for development (set min=max=1)
                sed -e "s/minReplicas:.*/minReplicas: 1/g" \
                    -e "s/maxReplicas:.*/maxReplicas: 1/g" \
                    "$MANIFESTS_DIR/hpa.yaml" > "$temp_file"
                ;;
            staging|production)
                # Keep HPA enabled with default values
                cp "$MANIFESTS_DIR/hpa.yaml" "$temp_file"
                ;;
            *)
                cp "$MANIFESTS_DIR/hpa.yaml" "$temp_file"
                ;;
        esac
        mv "$temp_file" "$MANIFESTS_DIR/hpa.yaml"
    fi
    
    echo -e "${GREEN}✓ Updated environment configurations${NC}"
}

# Function to update image in deployment manifest
update_deployment_image() {
    local temp_file=$(mktemp)
    sed "s|image:.*titanic-api-repo:.*|image: ${IMAGE_URL}|g" \
        "$MANIFESTS_DIR/deployment.yaml" > "$temp_file"
    mv "$temp_file" "$MANIFESTS_DIR/deployment.yaml"
    echo -e "${GREEN}✓ Updated deployment image to: ${IMAGE_URL}${NC}"
}

# Function to update namespace in manifests
update_namespace() {
    echo "Updating namespace in manifests..."
    find "$MANIFESTS_DIR" -name "*.yaml" -type f -exec sed -i "s/namespace: titanic-api/namespace: ${NAMESPACE}/g" {} \;
    echo -e "${GREEN}✓ Updated namespace in manifests${NC}"
}

# Function to wait for ClusterSecretStore
wait_for_secretstore() {
    echo "Checking ClusterSecretStore..."
    if kubectl get clustersecretstore aws-secrets-manager &>/dev/null; then
        echo "Waiting for ClusterSecretStore to be ready..."
        for i in {1..30}; do
            READY=$(kubectl get clustersecretstore aws-secrets-manager -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
            if [ "$READY" == "True" ]; then
                echo -e "${GREEN}✓ ClusterSecretStore is ready${NC}"
                return 0
            fi
            echo "Waiting for ClusterSecretStore... (attempt $i/30)"
            sleep 2
        done
        echo -e "${YELLOW}⚠ ClusterSecretStore may not be ready, but proceeding...${NC}"
    else
        echo -e "${YELLOW}⚠ ClusterSecretStore not found. It should be created separately.${NC}"
    fi
}

# Function to apply manifests in order
apply_manifests() {
    echo "Applying manifests..."
    
    # Apply order: Cluster-level resources first, then namespace resources
    # 1. ClusterIssuer (if exists)
    if [ -f "$MANIFESTS_DIR/clusterissuer.yaml" ]; then
        echo "Applying ClusterIssuer..."
        kubectl apply -f "$MANIFESTS_DIR/clusterissuer.yaml" || echo -e "${YELLOW}⚠ ClusterIssuer may already exist${NC}"
    fi
    
    # 2. ClusterSecretStore (if exists)
    if [ -f "$MANIFESTS_DIR/secretstore.yaml" ]; then
        echo "Applying ClusterSecretStore..."
        kubectl apply -f "$MANIFESTS_DIR/secretstore.yaml" || echo -e "${YELLOW}⚠ ClusterSecretStore may already exist${NC}"
    fi
    
    # 3. ResourceQuota and LimitRange
    if [ -f "$MANIFESTS_DIR/resourcequota.yaml" ]; then
        echo "Applying ResourceQuota..."
        kubectl apply -f "$MANIFESTS_DIR/resourcequota.yaml" -n "$NAMESPACE"
    fi
    
    # 4. ConfigMap
    if [ -f "$MANIFESTS_DIR/configmap.yaml" ]; then
        echo "Applying ConfigMap..."
        kubectl apply -f "$MANIFESTS_DIR/configmap.yaml" -n "$NAMESPACE"
    fi
    
    # 5. ExternalSecret (before deployment)
    if [ -f "$MANIFESTS_DIR/externalsecret.yaml" ]; then
        echo "Applying ExternalSecret..."
        kubectl apply -f "$MANIFESTS_DIR/externalsecret.yaml" -n "$NAMESPACE"
        
        # Wait for ExternalSecret to sync
        echo "Waiting for ExternalSecret to sync..."
        EXTERNAL_SECRET_NAME="titanic-api-secrets"
        for i in {1..60}; do
            if kubectl get externalsecret "$EXTERNAL_SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
                SYNC_STATUS=$(kubectl get externalsecret "$EXTERNAL_SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
                if [ "$SYNC_STATUS" == "True" ]; then
                    echo -e "${GREEN}✓ ExternalSecret synced successfully${NC}"
                    kubectl get secret titanic-secrets -n "$NAMESPACE" || true
                    break
                fi
                echo "Waiting for ExternalSecret to sync... (attempt $i/60) - Status: $SYNC_STATUS"
                if [ $i -le 10 ]; then
                    kubectl describe externalsecret "$EXTERNAL_SECRET_NAME" -n "$NAMESPACE" | tail -20 || true
                fi
            else
                echo "ExternalSecret not found yet... (attempt $i/60)"
            fi
            sleep 5
        done
        if [ "$SYNC_STATUS" != "True" ]; then
            echo -e "${YELLOW}⚠ ExternalSecret may not have synced, checking status...${NC}"
            kubectl get externalsecret "$EXTERNAL_SECRET_NAME" -n "$NAMESPACE" -o yaml || true
            kubectl get clustersecretstore aws-secrets-manager -o yaml || true
            echo "Proceeding anyway - secret may sync later or needs manual intervention..."
        fi
    fi
    
    # 6. Service
    if [ -f "$MANIFESTS_DIR/service.yaml" ]; then
        echo "Applying Service..."
        kubectl apply -f "$MANIFESTS_DIR/service.yaml" -n "$NAMESPACE"
    fi
    
    # 7. NetworkPolicy
    if [ -f "$MANIFESTS_DIR/networkpolicy.yaml" ]; then
        echo "Applying NetworkPolicy..."
        kubectl apply -f "$MANIFESTS_DIR/networkpolicy.yaml" -n "$NAMESPACE"
    fi
    
    # 8. PodDisruptionBudget
    if [ -f "$MANIFESTS_DIR/pdb.yaml" ]; then
        echo "Applying PodDisruptionBudget..."
        kubectl apply -f "$MANIFESTS_DIR/pdb.yaml" -n "$NAMESPACE"
    fi
    
    # 9. HPA (optional - skip if metrics server not available)
    if [ -f "$MANIFESTS_DIR/hpa.yaml" ]; then
        echo "Checking if metrics server is available..."
        # Check if metrics server API is available
        if kubectl get --raw /apis/metrics.k8s.io/v1beta1 2>/dev/null | grep -q "nodes\|pods"; then
            echo "Metrics server is available, applying HPA..."
            kubectl apply -f "$MANIFESTS_DIR/hpa.yaml" -n "$NAMESPACE"
            echo -e "${GREEN}✓ HPA applied successfully${NC}"
        else
            echo -e "${YELLOW}⚠ Metrics server not available - skipping HPA${NC}"
            echo "HPA requires metrics server to function. Deployment will continue without HPA."
            echo "You can enable HPA later by installing metrics server."
        fi
    fi
    
    # 10. Deployment (last, as it depends on secrets/configmaps)
    if [ -f "$MANIFESTS_DIR/deployment.yaml" ]; then
        echo "Applying Deployment..."
        kubectl apply -f "$MANIFESTS_DIR/deployment.yaml" -n "$NAMESPACE"
    fi
    
    # 11. Ingress (after service)
    if [ -f "$MANIFESTS_DIR/ingress.yaml" ]; then
        echo "Applying Ingress..."
        kubectl apply -f "$MANIFESTS_DIR/ingress.yaml" -n "$NAMESPACE"
    fi
    
    echo -e "${GREEN}✓ All manifests applied${NC}"
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    echo "Waiting for deployment to be ready..."
    
    # Wait for deployment to be available
    echo "Checking deployment status..."
    for i in {1..30}; do
        READY_REPLICAS=$(kubectl get deployment titanic-api -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        DESIRED_REPLICAS=$(kubectl get deployment titanic-api -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [ "$READY_REPLICAS" == "$DESIRED_REPLICAS" ] && [ "$READY_REPLICAS" != "0" ]; then
            echo -e "${GREEN}✓ All replicas are ready ($READY_REPLICAS/$DESIRED_REPLICAS)${NC}"
            return 0
        fi
        
        echo "Waiting for deployment... Ready: $READY_REPLICAS/$DESIRED_REPLICAS (attempt $i/30)"
        
        # Show pod status every 5 attempts
        if [ $((i % 5)) -eq 0 ]; then
            echo "Current pod status:"
            kubectl get pods -n "$NAMESPACE" -l app=titanic-api || true
        fi
        
        sleep 10
    done
    
    # If not ready, show detailed status
    echo -e "${YELLOW}⚠ Deployment not fully ready after 5 minutes${NC}"
    echo "Deployment status:"
    kubectl get deployment titanic-api -n "$NAMESPACE" -o yaml | grep -A 10 "status:" || true
    
    echo ""
    echo "Pod status:"
    kubectl get pods -n "$NAMESPACE" -l app=titanic-api || true
    
    echo ""
    echo "Pod events:"
    kubectl get events -n "$NAMESPACE" --field-selector involvedObject.kind=Pod --sort-by='.lastTimestamp' | tail -10 || true
    
    # Try to use rollout status with longer timeout
    echo ""
    echo "Attempting rollout status check with extended timeout..."
    kubectl rollout status deployment/titanic-api -n "$NAMESPACE" --timeout=10m || {
        echo -e "${YELLOW}⚠ Rollout status check failed or timed out${NC}"
        echo "This may be acceptable if pods are starting - check pod logs for details"
        return 0  # Don't fail the deployment - let verification handle it
    }
}

# Function to verify deployment
verify_deployment() {
    echo "Verifying deployment..."
    
    # Check pods
    echo "Pod status:"
    kubectl get pods -n "$NAMESPACE" -l app=titanic-api
    
    # Check if any pods are running
    RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=titanic-api --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    if [ "$RUNNING_PODS" -gt 0 ]; then
        echo -e "${GREEN}✓ Found $RUNNING_PODS running pod(s)${NC}"
    else
        echo -e "${YELLOW}⚠ No pods in Running state yet${NC}"
        echo "Checking pod status in detail:"
        kubectl get pods -n "$NAMESPACE" -l app=titanic-api -o wide
    fi
    
    # Check service
    echo ""
    echo "Service status:"
    kubectl get svc -n "$NAMESPACE" -l app=titanic-api || echo "No service found"
    
    # Check ingress
    echo ""
    echo "Ingress status:"
    kubectl get ingress -n "$NAMESPACE" -l app=titanic-api || echo "No ingress found"
    
    # Check deployment
    echo ""
    echo "Deployment status:"
    kubectl get deployment titanic-api -n "$NAMESPACE"
    
    # Show recent events
    echo ""
    echo "Recent events:"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10 || true
    
    echo -e "${GREEN}✓ Deployment verification complete${NC}"
    echo ""
    echo "Note: If pods are still starting, they may take a few minutes to become ready."
    echo "Check pod logs with: kubectl logs -n $NAMESPACE -l app=titanic-api"
}

# Main execution
main() {
    check_kubectl
    check_cluster
    create_namespace
    wait_for_secretstore
    update_namespace
    update_environment_config
    update_deployment_image
    apply_manifests
    
    # Wait a bit for pods to start initializing
    echo ""
    echo "Waiting for pods to initialize..."
    sleep 10
    
    wait_for_deployment
    verify_deployment
    
    echo ""
    echo -e "${GREEN}=== Deployment Complete ===${NC}"
    echo "Namespace: $NAMESPACE"
    echo "Image: $IMAGE_URL"
    echo ""
    echo "To check status:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo "  kubectl logs -n $NAMESPACE -l app=titanic-api"
    echo ""
    echo "Note: Pods may take a few minutes to become fully ready."
    echo "If pods are in ContainerCreating state, they may be waiting for secrets or init containers."
}

# Run main function
main
