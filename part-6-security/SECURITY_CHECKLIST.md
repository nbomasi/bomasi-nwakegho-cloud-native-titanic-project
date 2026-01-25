# Security Checklist

## Purpose

This checklist provides a systematic way to verify that all security controls are properly implemented and functioning. Use this checklist during deployments, security audits, and compliance reviews.

## Container Security

### ✅ Non-Root User
- [ ] Dockerfile uses non-root user (`appuser`)
- [ ] Kubernetes deployment enforces `runAsNonRoot: true`
- [ ] Pod security context sets `runAsUser: 1000`
- [ ] Verify: `kubectl exec <pod> -- whoami` returns `appuser`

**Verification Command:**
```bash
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.securityContext.runAsUser}'
# Should return: 1000
```

### ✅ Read-Only Root Filesystem
- [ ] Deployment sets `readOnlyRootFilesystem: true`
- [ ] Required writable directories mounted as volumes (`/tmp`, `/app/data`)
- [ ] Verify: Pod can write to `/tmp` but not to root filesystem

**Verification Command:**
```bash
kubectl exec <pod-name> -n <namespace> -- touch /test
# Should fail with "read-only file system"
kubectl exec <pod-name> -n <namespace> -- touch /tmp/test
# Should succeed
```

### ✅ Dropped Linux Capabilities
- [ ] Security context drops all capabilities: `capabilities: drop: [ALL]`
- [ ] No privileged containers
- [ ] Verify: Container cannot perform privileged operations

**Verification Command:**
```bash
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].securityContext.capabilities}'
# Should show: {"drop":["ALL"]}
```

### ✅ Image Vulnerability Scanning
- [ ] Trivy filesystem scan runs in CI pipeline
- [ ] Trivy image scan runs after build
- [ ] Results uploaded to GitHub Security tab
- [ ] Critical/High vulnerabilities reviewed

**Verification:**
- Check GitHub Actions workflow: `.github/workflows/ci.yml`
- Review GitHub Security tab for vulnerabilities
- Verify Trivy scans both filesystem and images

### ✅ Secret Management
- [ ] No secrets hardcoded in code
- [ ] No secrets in Git repository
- [ ] Secrets stored in AWS Secrets Manager
- [ ] External Secrets Operator syncing secrets
- [ ] ClusterSecretStore is ready
- [ ] Kubernetes secrets created from ExternalSecret

**Verification Commands:**
```bash
# Check ClusterSecretStore
kubectl get clustersecretstore aws-secrets-manager
# Should show: READY=True

# Check ExternalSecret
kubectl get externalsecret -n <namespace>
# Should show: READY=True

# Check Kubernetes secret exists
kubectl get secret <secret-name> -n <namespace>
# Should exist and contain expected keys

# Verify no secrets in code
grep -r "password\|secret\|key" titanic-api/src/ --exclude-dir=__pycache__ | grep -v "JWT_SECRET_KEY\|DATABASE_URL" | grep -v "import\|from"
# Should not find hardcoded secrets
```

## Network Security

### ✅ Network Policies
- [ ] Network policies defined for application pods
- [ ] Network policies defined for database pods
- [ ] Policies restrict ingress traffic
- [ ] Policies restrict egress traffic
- [ ] DNS access allowed for service discovery

**Verification Commands:**
```bash
# List network policies
kubectl get networkpolicy -n <namespace>

# Describe network policy
kubectl describe networkpolicy <policy-name> -n <namespace>

# Test connectivity
kubectl exec <app-pod> -n <namespace> -- curl <db-pod>:5432
# Should succeed (allowed by policy)

kubectl exec <random-pod> -n <namespace> -- curl <db-pod>:5432
# Should fail (blocked by policy)
```

### ✅ TLS/SSL Encryption
- [ ] cert-manager installed in cluster
- [ ] ClusterIssuer created and ready
- [ ] Ingress configured with TLS
- [ ] Certificate issued successfully
- [ ] HTTP to HTTPS redirect enabled

**Verification Commands:**
```bash
# Check cert-manager installation
kubectl get pods -n cert-manager
# Should show running pods

# Check ClusterIssuer
kubectl get clusterissuer letsencrypt-prod
# Should show: READY=True

# Check certificate
kubectl get certificate -n <namespace>
# Should show: READY=True

# Check certificate details
kubectl describe certificate <cert-name> -n <namespace>
# Should show issued certificate

# Test TLS
curl -v https://titanic-api.iyere.site/health
# Should show valid TLS certificate
```

### ✅ Database Encryption
- [ ] RDS encryption at rest enabled
- [ ] Database connection uses SSL/TLS
- [ ] Connection string includes SSL parameters

**Verification:**
- Check RDS configuration in AWS Console
- Verify connection string includes `sslmode=require`
- Check database logs for SSL connections

## Access Control

### ✅ Kubernetes RBAC
- [ ] Service accounts created with minimal permissions
- [ ] No cluster-admin bindings for application
- [ ] Role-based access control configured

**Verification Commands:**
```bash
# List service accounts
kubectl get serviceaccounts -n <namespace>

# Check RBAC bindings
kubectl get rolebindings,clusterrolebindings -n <namespace>

# Verify no excessive permissions
kubectl describe role <role-name> -n <namespace>
```

### ✅ IAM Policies (Least Privilege)
- [ ] EKS cluster role has minimal required policies
- [ ] Node role uses minimal worker node policy
- [ ] External Secrets role has Secrets Manager read only
- [ ] No overly permissive IAM policies

**Verification:**
- Review IAM policies in AWS Console
- Check Terraform IAM module configuration
- Verify policies follow least privilege principle

### ✅ IRSA (IAM Roles for Service Accounts)
- [ ] OIDC provider configured for EKS
- [ ] Service accounts annotated with IAM role ARN
- [ ] External Secrets Operator uses IRSA
- [ ] No long-lived AWS credentials

**Verification Commands:**
```bash
# Check OIDC provider
aws eks describe-cluster --name <cluster-name> --query "identity.oidc.issuer"

# Check service account annotation
kubectl get serviceaccount external-secrets-operator -n external-secrets-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# Should show IAM role ARN

# Verify IRSA working
kubectl exec -n external-secrets-system <pod> -- aws sts get-caller-identity
# Should show assumed role, not access key
```

## Application Security

### ⚠️ API Authentication/Authorization
- [ ] JWT_SECRET_KEY configured in secrets
- [ ] Authentication middleware implemented
- [ ] Protected endpoints require authentication
- [ ] Authorization checks implemented
- [ ] Token validation working

**Verification:**
- Review application code for auth middleware
- Test protected endpoints without token (should fail)
- Test with valid token (should succeed)

## Compliance & Monitoring

### ✅ Security Scanning
- [ ] Trivy scans run on every build
- [ ] Bandit scans Python code
- [ ] Results visible in GitHub Security tab
- [ ] Critical vulnerabilities block deployment

**Verification:**
- Check GitHub Actions workflow runs
- Review GitHub Security tab
- Verify scan results are uploaded

### ✅ Audit Logging
- [ ] Application logs structured (JSON format)
- [ ] Kubernetes audit logs enabled
- [ ] AWS CloudTrail logging IAM actions
- [ ] Log retention policy configured

**Verification:**
- Check application logs format
- Review CloudTrail logs in AWS Console
- Verify log retention settings

## Deployment Security

### ✅ CI/CD Security
- [ ] Secrets stored in GitHub Secrets (not code)
- [ ] No secrets exposed in logs
- [ ] Deployment requires approval (production)
- [ ] Rollback mechanism in place

**Verification:**
- Review GitHub Secrets configuration
- Check workflow logs for secret exposure
- Verify deployment approval gates

### ✅ Image Security
- [ ] Images scanned before push
- [ ] Only signed images deployed (if applicable)
- [ ] Image pull policy set to `Always` or `IfNotPresent`
- [ ] Base images from trusted sources

**Verification:**
- Check Dockerfile base image
- Review Trivy scan results
- Verify image pull policy in deployment

## Quick Verification Script

```bash
#!/bin/bash
# Quick security verification script

NAMESPACE="titanic-api-prod"

echo "=== Container Security ==="
echo "Non-root user:"
kubectl get pod -n $NAMESPACE -o jsonpath='{.items[0].spec.securityContext.runAsUser}' && echo ""

echo "Read-only rootfs:"
kubectl get pod -n $NAMESPACE -o jsonpath='{.items[0].spec.containers[0].securityContext.readOnlyRootFilesystem}' && echo ""

echo "=== Network Security ==="
echo "Network Policies:"
kubectl get networkpolicy -n $NAMESPACE

echo "=== TLS/SSL ==="
echo "ClusterIssuer:"
kubectl get clusterissuer letsencrypt-prod

echo "Certificates:"
kubectl get certificate -n $NAMESPACE

echo "=== Secrets Management ==="
echo "ClusterSecretStore:"
kubectl get clustersecretstore aws-secrets-manager

echo "ExternalSecret:"
kubectl get externalsecret -n $NAMESPACE

echo "=== Access Control ==="
echo "Service Accounts:"
kubectl get serviceaccounts -n $NAMESPACE

echo "=== Security Scanning ==="
echo "Check GitHub Security tab for Trivy results"
```

## Compliance Checklist

### OWASP Top 10
- [x] A01:2021 – Broken Access Control (Network policies, RBAC)
- [x] A02:2021 – Cryptographic Failures (TLS/SSL, encryption at rest)
- [x] A03:2021 – Injection (Parameterized queries, SQLAlchemy ORM)
- [x] A04:2021 – Insecure Design (Security by design, defense-in-depth)
- [x] A05:2021 – Security Misconfiguration (Hardened containers, least privilege)
- [x] A06:2021 – Vulnerable Components (Trivy scanning, dependency updates)
- [x] A07:2021 – Authentication Failures (JWT configured, middleware needed)
- [x] A08:2021 – Software and Data Integrity (Image scanning, signed images)
- [x] A09:2021 – Security Logging (Structured logging, audit trails)
- [x] A10:2021 – Server-Side Request Forgery (Network policies, egress restrictions)

### CIS Docker Benchmark
- [x] Non-root user
- [x] Read-only root filesystem
- [x] Dropped capabilities
- [x] Image scanning
- [x] Minimal base images

### Kubernetes Security Best Practices
- [x] Pod security standards
- [x] Network policies
- [x] RBAC
- [x] Secrets management
- [x] Resource limits
- [x] Security contexts

## Regular Security Tasks

### Daily
- [ ] Review GitHub Security tab for new vulnerabilities
- [ ] Check deployment status and pod health
- [ ] Review application logs for security events

### Weekly
- [ ] Review Trivy scan results
- [ ] Check certificate expiration dates
- [ ] Verify network policies are working
- [ ] Review IAM access logs

### Monthly
- [ ] Update dependencies (security patches)
- [ ] Review and rotate secrets
- [ ] Security audit of configurations
- [ ] Review compliance checklist

### Quarterly
- [ ] Full security assessment
- [ ] Penetration testing
- [ ] Review and update security policies
- [ ] Compliance review

## Incident Response Checklist

### When Vulnerability Detected
1. [ ] Assess severity (Critical/High/Medium/Low)
2. [ ] Check if exploit exists
3. [ ] Review affected components
4. [ ] Apply patch or workaround
5. [ ] Rebuild and redeploy
6. [ ] Verify fix
7. [ ] Document incident

### When Secret Compromised
1. [ ] Rotate secret immediately in AWS Secrets Manager
2. [ ] Verify ExternalSecret syncs new value
3. [ ] Restart pods to pick up new secret
4. [ ] Review access logs for unauthorized access
5. [ ] Document incident and remediation

### When Container Compromised
1. [ ] Isolate affected pod (network policies help)
2. [ ] Review logs for attack vector
3. [ ] Terminate compromised pod
4. [ ] Review and patch vulnerability
5. [ ] Redeploy with fixes
6. [ ] Document incident

## Sign-Off

**Security Review Date**: _______________

**Reviewed By**: _______________

**Status**: ☐ Pass  ☐ Fail  ☐ Needs Improvement

**Notes**:
_________________________________________________
_________________________________________________
_________________________________________________
