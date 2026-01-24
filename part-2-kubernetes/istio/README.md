# Istio Service Mesh Integration

This directory contains Istio service mesh configuration for the Titanic API deployment.

## Prerequisites

- Istio installed in the cluster
- Istio sidecar injection enabled for the namespace
- Istio ingress gateway deployed

## Installation

### 1. Enable Istio Sidecar Injection

```bash
# Label namespace for automatic sidecar injection
kubectl label namespace titanic-api istio-injection=enabled

# Or manually inject sidecars
istioctl kube-inject -f ../manifests/deployment.yaml | kubectl apply -f - -n titanic-api
```

### 2. Deploy Istio Resources

```bash
# Apply all Istio resources
kubectl apply -f istio/

# Or apply individually
kubectl apply -f istio/gateway.yaml
kubectl apply -f istio/virtualservice.yaml
kubectl apply -f istio/destinationrule.yaml
kubectl apply -f istio/authorizationpolicy.yaml
kubectl apply -f istio/peerauthentication.yaml
```

## Components

### Gateway

**File:** `gateway.yaml`

Defines the entry point for external traffic.

- HTTP on port 80
- HTTPS on port 443 with TLS
- Supports multiple hosts (dev, staging, prod)

### VirtualService

**File:** `virtualservice.yaml`

Defines traffic routing rules.

**Features:**
- Route traffic to titanic-api service
- Retry logic (3 attempts, 10s timeout)
- Request timeout (30s)
- CORS policy
- Health check endpoint with shorter timeout

### DestinationRule

**File:** `destinationrule.yaml`

Defines load balancing and circuit breaker policies.

**Application (titanic-api):**
- Load balancing: LEAST_CONN
- Connection pool: 100 max connections
- Circuit breaker: 5 consecutive errors trigger ejection
- mTLS: ISTIO_MUTUAL
- Subsets for version-based routing (v1, v2)

**Database (titanic-db):**
- Load balancing: ROUND_ROBIN
- Connection pool: 10 max connections
- mTLS: ISTIO_MUTUAL

### AuthorizationPolicy

**File:** `authorizationpolicy.yaml`

Defines access control policies.

**Application:**
- Allow internal service-to-service communication
- Allow external access to /health endpoint
- Restrict other endpoints to internal namespace

**Database:**
- Only allow access from titanic-api service account
- Port 5432 only

### PeerAuthentication

**File:** `peerauthentication.yaml`

Enforces mutual TLS (mTLS) between services.

- STRICT mode for all titanic-api pods
- Ensures encrypted communication between services

## Benefits

1. **Traffic Management:**
   - Advanced load balancing (LEAST_CONN, ROUND_ROBIN)
   - Circuit breakers prevent cascading failures
   - Retry logic for transient failures

2. **Security:**
   - Mutual TLS (mTLS) between services
   - Fine-grained authorization policies
   - Network-level security

3. **Observability:**
   - Automatic metrics collection
   - Distributed tracing
   - Service mesh telemetry

4. **Resilience:**
   - Circuit breakers
   - Timeout and retry policies
   - Connection pooling

## Usage

### Access via Istio Ingress Gateway

```bash
# Get Istio ingress gateway IP
export INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Access via HTTP
curl -H "Host: titanic-api.example.com" http://$INGRESS_HOST/

# Access via HTTPS
curl -H "Host: titanic-api.example.com" https://$INGRESS_HOST/ -k
```

### View Istio Metrics

```bash
# View service metrics
istioctl proxy-config cluster deployment/titanic-api

# View route configuration
istioctl proxy-config route deployment/titanic-api

# View listeners
istioctl proxy-config listener deployment/titanic-api
```

### Distributed Tracing

Istio automatically generates traces. Access via:
- Jaeger (if installed)
- Zipkin (if installed)
- Kiali (if installed)

## Verification

```bash
# Check Gateway
kubectl get gateway -n titanic-api

# Check VirtualService
kubectl get virtualservice -n titanic-api

# Check DestinationRule
kubectl get destinationrule -n titanic-api

# Check AuthorizationPolicy
kubectl get authorizationpolicy -n titanic-api

# Check PeerAuthentication
kubectl get peerauthentication -n titanic-api

# Verify sidecar injection
kubectl get pods -l app=titanic-api -n titanic-api -o jsonpath='{.items[0].spec.containers[*].name}'
# Should show: api istio-proxy
```

## Troubleshooting

### Sidecar Not Injected

```bash
# Check namespace label
kubectl get namespace titanic-api --show-labels

# Enable injection
kubectl label namespace titanic-api istio-injection=enabled --overwrite

# Restart pods
kubectl rollout restart deployment/titanic-api -n titanic-api
```

### mTLS Issues

```bash
# Check PeerAuthentication
kubectl get peerauthentication -n titanic-api

# Verify mTLS status
istioctl authn tls-check titanic-api.titanic-api.svc.cluster.local
```

### Traffic Not Routing

```bash
# Check VirtualService
kubectl describe virtualservice titanic-api-vs -n titanic-api

# Check Gateway
kubectl describe gateway titanic-api-gateway -n titanic-api

# View proxy logs
kubectl logs -l app=titanic-api -c istio-proxy -n titanic-api
```

## Integration with Existing Deployment

The Istio resources work alongside the existing Kubernetes manifests:

1. Deploy standard Kubernetes resources first
2. Enable Istio sidecar injection
3. Deploy Istio resources
4. Traffic flows through Istio gateway instead of standard Ingress

## Notes

- Istio Gateway replaces the standard Ingress resource
- Service mesh provides additional observability and security
- mTLS adds encryption overhead but improves security
- Circuit breakers help prevent cascading failures
- Distributed tracing requires additional components (Jaeger/Zipkin)
