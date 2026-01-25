#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Change to terraform directory if script is in parent directory
if [ -d "terraform" ]; then
    cd terraform
fi

ENVIRONMENT="${ENVIRONMENT:-prod}"
TF_VAR_FILE="environments/${ENVIRONMENT}/terraform.tfvars"
BACKEND_CONF="environments/${ENVIRONMENT}/backend.conf"
AWS_PROFILE="${AWS_PROFILE:-iyere}"
AWS_REGION="${AWS_REGION:-eu-west-2}"

DOMAIN_NAME="titanic-api.iyere.site"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.13.3}"
EXTERNAL_DNS_CHART_VERSION="${EXTERNAL_DNS_CHART_VERSION:-}"
KUBE_PROMETHEUS_STACK_VERSION="${KUBE_PROMETHEUS_STACK_VERSION:-56.8.0}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    command -v terraform >/dev/null 2>&1 || error "terraform is not installed"
    command -v helm >/dev/null 2>&1 || error "helm is not installed"
    command -v kubectl >/dev/null 2>&1 || error "kubectl is not installed"
    command -v aws >/dev/null 2>&1 || error "aws cli is not installed"
    command -v jq >/dev/null 2>&1 || error "jq is not installed (required for parsing Terraform outputs)"
    
    if [ ! -f "$TF_VAR_FILE" ]; then
        error "Terraform variables file not found: $TF_VAR_FILE"
    fi
    
    log "Prerequisites check passed"
}

init_terraform_backend() {
    log "Initializing Terraform backend..."
    
    if [ ! -f "$BACKEND_CONF" ]; then
        error "Backend configuration file not found: $BACKEND_CONF"
    fi
    
    terraform init -backend-config="$BACKEND_CONF" -reconfigure >/dev/null 2>&1 || {
        log "WARNING: Terraform init failed, trying without reconfigure..."
        terraform init -backend-config="$BACKEND_CONF" >/dev/null 2>&1 || error "Failed to initialize Terraform backend"
    }
    
    log "Terraform backend initialized"
}

get_terraform_output() {
    local output_name="$1"
    terraform output -json "$output_name" 2>/dev/null | jq -r ".${output_name}.value // empty" || echo ""
}

get_terraform_output_raw() {
    local output_name="$1"
    terraform output -raw "$output_name" 2>/dev/null || echo ""
}

configure_kubectl() {
    log "Configuring kubectl..."
    
    CLUSTER_NAME=$(get_terraform_output_raw "cluster_name")
    if [ -z "$CLUSTER_NAME" ] || [ "$CLUSTER_NAME" = "null" ]; then
        error "Could not determine cluster name from Terraform outputs. Make sure Terraform has been applied."
    fi
    
    # Trim whitespace and validate cluster name length
    CLUSTER_NAME=$(echo "$CLUSTER_NAME" | xargs)
    if [ ${#CLUSTER_NAME} -gt 100 ]; then
        error "Cluster name is too long (${#CLUSTER_NAME} characters, max 100): $CLUSTER_NAME"
    fi
    
    log "Using cluster: $CLUSTER_NAME"
    
    if [ -n "$AWS_PROFILE" ] && [ "$AWS_PROFILE" != "" ]; then
        aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" || error "Failed to update kubeconfig"
    else
        aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" || error "Failed to update kubeconfig"
    fi
    
    kubectl cluster-info >/dev/null 2>&1 || error "Failed to connect to cluster"
    log "kubectl configured successfully"
}

get_irsa_role_arn() {
    local service="$1"
    local role_arn
    
    role_arn=$(get_terraform_output_raw "${service}_role_arn")
    if [ -z "$role_arn" ] || [ "$role_arn" = "null" ]; then
        error "Could not get ${service} IRSA role ARN from Terraform outputs. Make sure Terraform has been applied and IRSA roles are created."
    fi
    
    echo "$role_arn"
}

get_route53_zone_id() {
    local zone_id
    
    zone_id=$(get_terraform_output_raw "route53_zone_id")
    if [ -z "$zone_id" ] || [ "$zone_id" = "null" ]; then
        log "WARNING: Could not get Route53 zone ID from Terraform outputs. External DNS will manage all hosted zones."
        echo ""
    else
        echo "$zone_id"
    fi
}

add_helm_repos() {
    log "Adding Helm repositories..."
    
    helm repo add jetstack https://charts.jetstack.io --force-update || true
    helm repo add external-dns https://kubernetes-sigs.github.io/external-dns --force-update || true
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update || true
    
    log "Updating Helm repositories..."
    helm repo update jetstack external-dns prometheus-community
    
    log "Helm repositories configured"
}

create_temp_values_file() {
    local values_content="$1"
    local temp_file
    
    if command -v mktemp >/dev/null 2>&1; then
        temp_file=$(mktemp)
    else
        temp_file="/tmp/helm-values-$$.yaml"
        if [ -n "${TMPDIR:-}" ]; then
            temp_file="${TMPDIR}/helm-values-$$.yaml"
        elif [ -n "${TEMP:-}" ]; then
            temp_file="${TEMP}/helm-values-$$.yaml"
        fi
    fi
    
    echo "$values_content" > "$temp_file"
    echo "$temp_file"
}

cleanup_temp_file() {
    local temp_file="$1"
    if [ -f "$temp_file" ]; then
        rm -f "$temp_file" 2>/dev/null || true
    fi
}

deploy_cert_manager() {
    log "Deploying cert-manager..."
    
    local namespace="cert-manager"
    local service_account="cert-manager"
    local cert_manager_role_arn
    
    cert_manager_role_arn=$(get_irsa_role_arn "cert_manager")
    log "Using cert-manager IRSA role: $cert_manager_role_arn"
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log "Namespace $namespace already exists"
    else
        kubectl create namespace "$namespace" || error "Failed to create namespace $namespace"
        kubectl label namespace "$namespace" cert-manager.io/disable-validation=true --overwrite || true
    fi
    
    local helm_values="
installCRDs: true
global:
  leaderElection:
    namespace: $namespace
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: $cert_manager_role_arn
  name: $service_account
"
    
    local values_file
    values_file=$(create_temp_values_file "$helm_values")
    trap "cleanup_temp_file '$values_file'" EXIT
    
    if helm list -n "$namespace" | grep -q "^cert-manager[[:space:]]"; then
        log "cert-manager already installed, upgrading..."
        helm upgrade cert-manager jetstack/cert-manager \
            --version "$CERT_MANAGER_VERSION" \
            --namespace "$namespace" \
            --values "$values_file" \
            --wait \
            --timeout 30m || error "Failed to upgrade cert-manager"
    else
        log "Installing cert-manager..."
        helm install cert-manager jetstack/cert-manager \
            --version "$CERT_MANAGER_VERSION" \
            --namespace "$namespace" \
            --create-namespace \
            --values "$values_file" \
            --wait \
            --timeout 30m || error "Failed to install cert-manager"
    fi
    
    cleanup_temp_file "$values_file"
    trap - EXIT
    
    log "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n "$namespace" --timeout=5m || log "WARNING: Some cert-manager pods may not be ready yet"
    
    log "cert-manager deployed successfully"
}

deploy_external_dns() {
    log "Deploying external-dns..."
    
    local namespace="external-dns-system"
    local service_account="external-dns"
    local external_dns_role_arn
    local route53_zone_id
    local txt_owner_id="${EXTERNAL_DNS_TXT_OWNER_ID:-titanic-api-${ENVIRONMENT}}"
    
    external_dns_role_arn=$(get_irsa_role_arn "external_dns")
    log "Using external-dns IRSA role: $external_dns_role_arn"
    
    route53_zone_id=$(get_route53_zone_id)
    if [ -n "$route53_zone_id" ]; then
        log "Using Route53 zone ID: $route53_zone_id"
    else
        log "No Route53 zone ID found, external-dns will manage all hosted zones"
    fi
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log "Namespace $namespace already exists"
    else
        kubectl create namespace "$namespace" || error "Failed to create namespace $namespace"
    fi
    
    local helm_values="
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: $external_dns_role_arn
  name: $service_account

provider: aws

aws:
  region: $AWS_REGION

txtOwnerId: $txt_owner_id
domainFilters:
  - $DOMAIN_NAME
$(if [ -n "$route53_zone_id" ]; then echo "zoneIdFilters:
  - $route53_zone_id"; fi)

policy: upsert-only

logFormat: json
logLevel: info

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

podSecurityContext:
  fsGroup: 65534

securityContext:
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
  seccompProfile:
    type: RuntimeDefault
"
    
    local chart_version_arg=""
    if [ -n "$EXTERNAL_DNS_CHART_VERSION" ]; then
        chart_version_arg="--version $EXTERNAL_DNS_CHART_VERSION"
    fi
    
    local values_file
    values_file=$(create_temp_values_file "$helm_values")
    trap "cleanup_temp_file '$values_file'" EXIT
    
    if helm list -n "$namespace" | grep -q "^external-dns[[:space:]]"; then
        log "external-dns already installed, upgrading..."
        helm upgrade external-dns external-dns/external-dns \
            $chart_version_arg \
            --namespace "$namespace" \
            --values "$values_file" \
            --wait \
            --timeout 10m || error "Failed to upgrade external-dns"
    else
        log "Installing external-dns..."
        helm install external-dns external-dns/external-dns \
            $chart_version_arg \
            --namespace "$namespace" \
            --create-namespace \
            --values "$values_file" \
            --wait \
            --timeout 10m || error "Failed to install external-dns"
    fi
    
    cleanup_temp_file "$values_file"
    trap - EXIT
    
    log "external-dns deployed successfully"
}

deploy_kube_prometheus_stack() {
    log "Deploying kube-prometheus-stack..."
    
    local namespace="monitoring"
    local release_name="kube-prometheus-stack"
    local storage_class="${KUBE_PROMETHEUS_STACK_STORAGE_CLASS:-auto-ebs-sc}"
    local retention="${KUBE_PROMETHEUS_STACK_RETENTION:-30d}"
    local storage_size="${KUBE_PROMETHEUS_STACK_STORAGE_SIZE:-50Gi}"
    
    log "Using storage class: $storage_class"
    log "Using retention: $retention"
    log "Using storage size: $storage_size"
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log "Namespace $namespace already exists"
    else
        kubectl create namespace "$namespace" || error "Failed to create namespace $namespace"
    fi
    
    # Check if release exists in helm list (more robust check)
    local release_exists=false
    local helm_list_output
    helm_list_output=$(helm list -n "$namespace" 2>/dev/null || echo "")
    
    if echo "$helm_list_output" | grep -qE "^${release_name}[[:space:]]|^${release_name}$"; then
        release_exists=true
        log "Release $release_name found in helm list"
        log "Current releases in namespace:"
        echo "$helm_list_output" | head -5
    else
        log "Release $release_name not found in helm list"
        # Check if pods are running (might indicate a working release)
        if kubectl get pods -n "$namespace" -l app.kubernetes.io/name=prometheus 2>/dev/null | grep -q Running; then
            log "WARNING: Prometheus pods are running but release not in helm list. This might indicate an orphaned release."
            log "Attempting to check for release secrets..."
            local release_secrets
            release_secrets=$(kubectl get secret -n "$namespace" -o name 2>/dev/null | grep "sh.helm.release.v1.${release_name}" || echo "")
            if [ -n "$release_secrets" ]; then
                log "Found release secrets. The release might exist but helm list is not showing it."
                log "Trying to get release status directly..."
                if helm status "$release_name" -n "$namespace" >/dev/null 2>&1; then
                    release_exists=true
                    log "Release exists (confirmed via helm status)"
                fi
            fi
        fi
    fi
    
    # Check for orphaned Helm release secrets (only if release doesn't exist)
    if [ "$release_exists" = false ]; then
        local helm_secret_exists=false
        if kubectl get secret -n "$namespace" -l owner=helm 2>/dev/null | grep -q "sh.helm.release.v1.${release_name}"; then
            helm_secret_exists=true
            log "Found orphaned Helm release secret for $release_name (release not in helm list)"
            log "Cleaning up orphaned secrets..."
            kubectl delete secret -n "$namespace" -l owner=helm --field-selector metadata.name=sh.helm.release.v1.${release_name}.v* 2>/dev/null || {
                log "Attempting to delete release secrets manually..."
                for secret in $(kubectl get secret -n "$namespace" -o name 2>/dev/null | grep "sh.helm.release.v1.${release_name}"); do
                    kubectl delete "$secret" -n "$namespace" 2>/dev/null || true
                done
            }
            log "Orphaned release secrets cleaned up"
        fi
    fi
    
    local helm_values="
prometheus:
  prometheusSpec:
    retention: $retention
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          storageClassName: $storage_class
          resources:
            requests:
              storage: $storage_size
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi

grafana:
  adminPassword: admin
  adminUser: admin
  persistence:
    enabled: true
    size: 10Gi
    storageClassName: $storage_class
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  ingress:
    enabled: false

alertmanager:
  alertmanagerSpec:
    retention: 120h
    storage:
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          storageClassName: $storage_class
          resources:
            requests:
              storage: 10Gi
"
    
    if [ -n "${GRAFANA_ADMIN_PASSWORD:-}" ]; then
        log "Using GRAFANA_ADMIN_PASSWORD from environment variable"
        helm_values=$(echo "$helm_values" | sed "s/adminPassword: admin/adminPassword: $GRAFANA_ADMIN_PASSWORD/g")
    else
        log "WARNING: GRAFANA_ADMIN_PASSWORD not set. Using default password 'admin'."
        log "Set GRAFANA_ADMIN_PASSWORD environment variable for production use."
        log "Note: You can manage Grafana password via External Secrets Operator after deployment."
    fi
    
    local values_file
    values_file=$(create_temp_values_file "$helm_values")
    trap "cleanup_temp_file '$values_file'" EXIT
    
    if [ "$release_exists" = true ]; then
        log "kube-prometheus-stack already installed, upgrading..."
        helm upgrade "$release_name" prometheus-community/kube-prometheus-stack \
            --version "$KUBE_PROMETHEUS_STACK_VERSION" \
            --namespace "$namespace" \
            --values "$values_file" \
            --wait \
            --timeout 30m || error "Failed to upgrade kube-prometheus-stack"
    else
        # Clean up any orphaned release secrets before installing
        log "Checking for orphaned release secrets before installation..."
        local orphaned_secrets
        orphaned_secrets=$(kubectl get secret -n "$namespace" -o name 2>/dev/null | grep "sh.helm.release.v1.${release_name}" || echo "")
        
        if [ -n "$orphaned_secrets" ]; then
            log "Found orphaned Helm release secrets. Cleaning up before installation..."
            for secret in $orphaned_secrets; do
                kubectl delete "$secret" -n "$namespace" 2>/dev/null || true
            done
            log "Cleanup completed"
        fi
        
        log "Installing kube-prometheus-stack..."
        helm install "$release_name" prometheus-community/kube-prometheus-stack \
            --version "$KUBE_PROMETHEUS_STACK_VERSION" \
            --namespace "$namespace" \
            --create-namespace \
            --values "$values_file" \
            --wait \
            --timeout 30m || error "Failed to install kube-prometheus-stack"
    fi
    
    cleanup_temp_file "$values_file"
    trap - EXIT
    
    log "Waiting for kube-prometheus-stack to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n "$namespace" --timeout=10m || log "WARNING: Prometheus pods may not be ready yet"
    
    log "kube-prometheus-stack deployed successfully"
}

main() {
    log "Starting Helm chart deployment for $ENVIRONMENT environment"
    log "Domain: $DOMAIN_NAME"
    log "AWS Region: $AWS_REGION"
    log "AWS Profile: ${AWS_PROFILE:-default}"
    
    check_prerequisites
    init_terraform_backend
    configure_kubectl
    add_helm_repos
    
    log ""
    log "=== Deploying cert-manager ==="
    deploy_cert_manager
    
    log ""
    log "=== Deploying external-dns ==="
    deploy_external_dns
    
    log ""
    log "=== Deploying kube-prometheus-stack ==="
    deploy_kube_prometheus_stack
    
    log ""
    log "=== Deployment Summary ==="
    log "cert-manager: deployed in cert-manager namespace"
    log "external-dns: deployed in external-dns-system namespace"
    log "kube-prometheus-stack: deployed in monitoring namespace"
    log ""
    log "To verify deployments:"
    log "  kubectl get pods -n cert-manager"
    log "  kubectl get pods -n external-dns-system"
    log "  kubectl get pods -n monitoring"
    log ""
    log "Deployment completed successfully!"
}

main "$@"
