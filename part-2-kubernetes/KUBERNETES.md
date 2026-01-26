# Part 2: Kubernetes Deployment

## Executive Summary

This document describes the Kubernetes manifest definitions and configuration for the Titanic API, implementing production-ready orchestration with comprehensive resource management, security policies, and high availability features. The implementation includes all required core manifests, advanced Kubernetes features, and deployment strategies to ensure zero-downtime deployments with proper rollback mechanisms.

**Note:** This part focuses on defining Kubernetes manifests and configuration. The actual deployment to EKS is performed via CI/CD pipelines in Part 3. The EKS cluster infrastructure was provisioned in Part 5 (Infrastructure as Code).

## Table of Contents

1. [Requirements Overview](#requirements-overview)
2. [Manifests Overview](#manifests-overview)
3. [Core Manifests](#core-manifests)
4. [Advanced Features](#advanced-features)
5. [Deployment Strategy](#deployment-strategy)
6. [Manifest Testing and Verification](#manifest-testing-and-verification)
7. [Compliance with Requirements](#compliance-with-requirements)
8. [Known Limitations](#known-limitations)
9. [References](#references)
10. [Conclusion](#conclusion)

## Requirements Overview

### 1. Core Manifests

**Requirement:** Deployment with resource limits, Services (ClusterIP and Ingress), ConfigMap, Secret management, and external database connectivity.

**Implementation Status:** Complete

- Deployment with proper resource requests and limits
- ClusterIP Service for internal communication
- Ingress for HTTP/HTTPS routing (external access)
- ConfigMap for non-sensitive configuration
- ExternalSecret for secure secret management from AWS Secrets Manager
- ClusterSecretStore for AWS Secrets Manager integration
- External database (RDS PostgreSQL) connectivity

### 2. Advanced Kubernetes Features

**Requirement:** HPA, liveness/readiness probes, Pod Disruption Budget, Network Policy, and resource quotas.

**Implementation Status:** Complete

- Horizontal Pod Autoscaler (HPA) based on CPU and memory metrics
- Liveness and readiness probes for application pods
- Pod Disruption Budget for high availability
- Network Policies allowing RDS access and restricting ingress
- Resource Quota and LimitRange for namespace resource management

### 3. Deployment Strategy

**Requirement:** Rolling update strategy, rollback mechanism, and zero-downtime deployment.

**Implementation Status:** Complete

- Rolling update strategy with maxSurge and maxUnavailable configuration
- Automatic rollback on deployment failure
- Zero-downtime deployment approach

## Manifests Overview

### File Structure

```
part-2-kubernetes/
├── manifests/
│   ├── deployment.yaml          # Application deployment
│   ├── service.yaml             # ClusterIP service
│   ├── configmap.yaml           # Non-sensitive configuration
│   ├── secret.yaml              # Reference only (ExternalSecret creates actual secret)
│   ├── secretstore.yaml         # ClusterSecretStore for AWS Secrets Manager
│   ├── externalsecret.yaml      # ExternalSecret for secret synchronization
│   ├── hpa.yaml                 # Horizontal Pod Autoscaler
│   ├── pdb.yaml                 # Pod Disruption Budget
│   ├── networkpolicy.yaml       # Network security policies
│   ├── resourcequota.yaml       # Resource quotas and limits
│   ├── ingress.yaml             # Ingress for HTTP/HTTPS routing
│   ├── clusterissuer.yaml       # Cert-manager ClusterIssuer
│   └── grafana-ingress.yaml     # Grafana ingress
├── helm/titanic-api/            # Helm chart
└── kustomize/                   # Kustomize overlays
```

### Manifest Descriptions

**Core Manifests:**
- `deployment.yaml` - Defines application pods with replicas, resource limits, health probes, and security contexts
- `service.yaml` - Creates ClusterIP service for internal pod-to-pod communication
- `configmap.yaml` - Stores non-sensitive configuration data (environment variables, app settings)
- `secret.yaml` - Reference template only (actual secret created by ExternalSecret)
- `ingress.yaml` - Configures HTTP/HTTPS routing with TLS termination and path-based routing

**Secret Management:**
- `secretstore.yaml` - ClusterSecretStore connecting to AWS Secrets Manager
- `externalsecret.yaml` - ExternalSecret synchronizing secrets from AWS Secrets Manager to Kubernetes

**Advanced Features:**
- `hpa.yaml` - Horizontal Pod Autoscaler configuration for automatic scaling based on CPU and memory
- `pdb.yaml` - Pod Disruption Budget ensuring minimum pod availability during disruptions
- `networkpolicy.yaml` - Network policies restricting pod ingress/egress traffic
- `resourcequota.yaml` - Resource quotas and limit ranges for namespace resource management
- `clusterissuer.yaml` - Cert-manager ClusterIssuer for automatic TLS certificate provisioning
- `grafana-ingress.yaml` - Ingress configuration for Grafana monitoring dashboard

### Helm Chart

**Purpose:** Package management and templating for Kubernetes resources

**Key Components:**
- `Chart.yaml` - Chart metadata and version information
- `values.yaml` - Default configuration values (replicas, resources, ingress, etc.)
- `templates/` - Templated Kubernetes manifests with parameterized values

**Benefits:**
- Single command deployment/upgrade
- Environment-specific value overrides
- Version management and rollback capabilities
- Template reusability across environments

### Kustomize Overlays

**Purpose:** Environment-specific configuration without manifest duplication

**Structure:**
- `base/` - Base manifests shared across all environments
- `overlays/dev/` - Development environment customizations (1 replica, reduced resources)
- `overlays/staging/` - Staging environment customizations (2 replicas, standard resources)
- `overlays/prod/` - Production environment customizations (2 replicas, enhanced resources)

**Benefits:**
- Single source of truth (base manifests)
- Environment-specific patches (namespace, replicas, resources, image tags)
- No manifest duplication
- Easy maintenance and updates

## Core Manifests

### Deployment

**Application Deployment:**
- Replicas: 2-10 (managed by HPA, scales based on CPU 70% and memory 80% thresholds)
- Strategy: RollingUpdate (maxSurge: 1, maxUnavailable: 0)
- Security: Non-root user (UID 1000), read-only root filesystem
- Resources: CPU 100m-500m, Memory 512Mi-1Gi
- Probes: Liveness and readiness on /health endpoint
- Image: ECR repository (456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo:latest)

**Database:** External managed service (AWS RDS PostgreSQL) via VPC private subnet. Credentials managed via AWS Secrets Manager and ExternalSecret.

### Service

**ClusterIP Service (titanic-api):**
- Internal service for application pods
- Port: 80 → 5000 (http)
- Session affinity: ClientIP (3 hours)
- External access handled by Ingress controller

### ConfigMap

**Configuration Data:** flask-env, postgres-db, app-name, app-version, log-level

### Secret Management

**ExternalSecret Integration:**
- ClusterSecretStore: Configured for AWS Secrets Manager
- ExternalSecret: Synchronizes secrets from AWS Secrets Manager
- Secret Name: `titanic-secrets` (created automatically)
- Secret Keys: `database-url` (constructed from RDS credentials), `jwt-secret-key` (from AWS Secrets Manager)

**AWS Secrets Manager:** Secret name `titanic-api-prod-rds-credentials` with keys: `postgres-rds-endpoint`, `postgres-rds-dbname`, `postgres-rds-dbuser`, `postgres-rds-password`, `jwt_secret_key`

## Advanced Features

### Horizontal Pod Autoscaler (HPA)

**Configuration:**
- Min Replicas: 2
- Max Replicas: 10
- CPU Threshold: 70% average utilization
- Memory Threshold: 80% average utilization

**Scaling Behavior:**
- Scale Up: Aggressive (100% increase or +2 pods per 30s)
- Scale Down: Conservative (50% decrease per 60s, 5min stabilization window)

**Benefits:**
- Automatic scaling based on demand
- Cost optimization during low traffic
- Performance maintenance during high traffic

### Liveness and Readiness Probes

**Application Probes:**
- Liveness: HTTP GET /health (60s initial, 30s interval, 10s timeout)
- Readiness: HTTP GET /health (30s initial, 10s interval, 10s timeout)
- Failure Threshold: 3 attempts

### Pod Disruption Budget (PDB)

**Configuration:** Min Available: 1 pod. Prevents voluntary disruptions from removing all pods.

### Network Policy

**Application Network Policy:**
- Ingress: Allow from any namespace on port 5000
- Egress: Allow to RDS (port 5432), DNS (port 53), HTTPS (port 443)

### Resource Quota and LimitRange

**Resource Quota:** CPU 2-4 cores, Memory 4Gi-8Gi, LoadBalancers: 0

**LimitRange:** Default CPU 500m/100m, Default Memory 1Gi/512Mi

### Ingress

**Configuration:** Ingress Class nginx, TLS enabled (cert-manager), SSL redirect, Host: titanic-api.iyere.site, Paths: `/`, `/health`, `/people`. Automatic certificate via Let's Encrypt.

## Deployment Strategy

### Rolling Update Strategy

**Configuration:** Type RollingUpdate, Max Surge: 1, Max Unavailable: 0

**Process:** New pod created → passes readiness probe → traffic routed → old pod terminated → repeats

**Benefits:** Zero-downtime deployments, gradual rollout, automatic rollback on failure

### Rollback Mechanism

**Automatic:** Kubernetes rolls back if deployment fails health checks

**Manual:** `kubectl rollout undo deployment/titanic-api` or `kubectl rollout undo deployment/titanic-api --to-revision=2`

### Zero-Downtime Deployment

**Achieved Through:** Rolling update (maxUnavailable: 0), readiness probes, multiple replicas (minimum 2), Pod Disruption Budget

## Manifest Testing and Verification

This section provides instructions for testing Kubernetes manifests locally or in a development cluster. **Actual deployment to EKS production is performed via CI/CD pipelines in Part 3.**

### Prerequisites for Local Testing

- Kubernetes cluster (v1.24+), kubectl configured
- Ingress controller, cert-manager, External Secrets Operator (for local testing)
- AWS RDS PostgreSQL instance and AWS Secrets Manager secret configured

### Local Testing Steps

```bash
# 1. Deploy ClusterIssuer, ClusterSecretStore, ExternalSecret
kubectl apply -f manifests/clusterissuer.yaml
kubectl apply -f manifests/secretstore.yaml
kubectl apply -f manifests/externalsecret.yaml

# 2. Wait for ExternalSecret to sync
kubectl wait --for=condition=Synced externalsecret/titanic-secrets -n titanic-api --timeout=5m

# 3. Deploy all manifests
kubectl apply -f manifests/

# 4. Verify deployment
kubectl get pods,services,ingress,externalsecret -n titanic-api
```

### Production Deployment

**Production deployment to EKS is performed automatically via CI/CD pipelines in Part 3.** The CI/CD pipelines build and push Docker images to ECR, deploy manifests to EKS using Helm or kubectl, perform health checks, and handle rollbacks on failure. The EKS cluster infrastructure was provisioned in Part 5 (Infrastructure as Code).

## Compliance with Requirements

### Requirement 1: Core Manifests

- [x] Deployment with proper resource limits and requests
- [x] Service (ClusterIP, Ingress handles external access)
- [x] Ingress for HTTP/HTTPS routing
- [x] ConfigMap for non-sensitive configuration
- [x] ExternalSecret for secure secret management from AWS Secrets Manager
- [x] ClusterSecretStore for AWS Secrets Manager integration
- [x] External database (RDS PostgreSQL) connectivity

### Requirement 2: Advanced Kubernetes Features

- [x] Horizontal Pod Autoscaler (HPA) based on CPU and memory metrics
- [x] Liveness and readiness probes
- [x] Pod Disruption Budget
- [x] Network Policy (restrict database access)
- [x] Resource quotas and limits

### Requirement 3: Deployment Strategy

- [x] Rolling update strategy implemented
- [x] Proper rollback mechanism (automatic and manual)
- [x] Zero-downtime deployment approach

## Known Limitations

None. All requirements have been fully implemented.

## References

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [External Secrets Operator](https://external-secrets.io/)
- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)

## Conclusion

Part 2: Kubernetes Deployment has been successfully completed with all requirements met. The implementation provides production-ready Kubernetes manifest definitions with comprehensive resource management, security hardening, and high availability configuration.

**Deployment Context:**
- **Part 5 (Infrastructure as Code):** Provisioned the EKS cluster infrastructure
- **Part 2 (Kubernetes):** Defines the Kubernetes manifests and configuration (this part)
- **Part 3 (CI/CD):** Performs actual deployment to EKS via automated pipelines

The Kubernetes manifests are ready for deployment via CI/CD pipelines in Part 3.
