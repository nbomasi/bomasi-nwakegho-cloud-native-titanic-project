# Part 6: Security & Compliance

**AWS Account**: 111122223333  
**Region**: eu-west-2 (London)  
**Project**: titanic-api

---

## Table of Contents

1. [Overview](#overview)
2. [Security Architecture](#security-architecture)
3. [Container Security](#container-security)
4. [Network Security](#network-security)
5. [Secrets Management](#secrets-management)
6. [Access Control](#access-control)
7. [API Security](#api-security)
8. [Compliance & Auditing](#compliance--auditing)
9. [Vulnerability Management](#vulnerability-management)
10. [Security Monitoring](#security-monitoring)
11. [Incident Response](#incident-response)
12. [References](#references)

---

## Overview

This document provides comprehensive documentation for security controls implemented across the Titanic API infrastructure. Security features have been implemented across Parts 1 (Containerization), Part 2 (Kubernetes), Part 3 (CI/CD), and Part 5 (Infrastructure as Code). Part 6 consolidates and documents these security measures, ensuring compliance with industry standards and best practices.

### Security Status Summary

**Container Security**: Complete
- Non-root user execution
- Read-only root filesystem
- Dropped Linux capabilities
- Image vulnerability scanning in CI/CD
- Secure secret management

**Network Security**: Complete
- Network policies for pod-to-pod restrictions
- TLS/SSL encryption for all endpoints
- Database encryption at rest

**Access Control**: Complete
- IRSA (IAM Roles for Service Accounts)
- Kubernetes RBAC
- Least privilege IAM policies
- GitHub Environments for deployment approvals

**API Security**: Complete
- JWT-based authentication
- Role-based authorization
- Protected endpoints

---

## Security Architecture

### Security Layers

```
Layer 1: Container Security
  - Non-root execution
  - Read-only root filesystem
  - Dropped Linux capabilities
  - Image vulnerability scanning

Layer 2: Network Security
  - Network policies (pod-to-pod restrictions)
  - TLS/SSL encryption (cert-manager + Let's Encrypt)
  - Database encryption at rest (RDS)

Layer 3: Secrets Management
  - AWS Secrets Manager (centralized storage)
  - External Secrets Operator (Kubernetes sync)
  - IRSA (IAM Roles for Service Accounts)
  - No hardcoded secrets

Layer 4: Access Control
  - Kubernetes RBAC
  - IAM policies (least privilege)
  - GitHub Environments (deployment approvals)
  - API authentication and authorization
```

### Defense-in-Depth Strategy

The infrastructure implements multiple layers of security controls to provide defense-in-depth:

1. **Prevention**: Container hardening, network segmentation, access controls
2. **Detection**: Vulnerability scanning, audit logging, monitoring
3. **Response**: Incident response procedures, automated remediation
4. **Recovery**: Backup strategies, disaster recovery plans

---

## Container Security

### Non-Root User Execution

**Implementation**:
- **Location**: `part-1-containerization/Dockerfile`
- **User**: `appuser` (UID 1000, GID 1000)
- **Kubernetes Enforcement**: `part-2-kubernetes/manifests/deployment.yaml`
  - Pod security context: `runAsNonRoot: true`, `runAsUser: 1000`

**Security Benefit**:
- Reduces attack surface by preventing privilege escalation
- Limits damage if container is compromised
- Compliance with security best practices

**Verification**:
```bash
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.securityContext.runAsUser}'
# Should return: 1000
```

### Read-Only Root Filesystem

**Implementation**:
- **Location**: `part-2-kubernetes/manifests/deployment.yaml`
- **Configuration**: `readOnlyRootFilesystem: true`
- **Writable Volumes**: `/tmp` and `/app/data` mounted as volumes

**Security Benefit**:
- Prevents malicious code from writing to filesystem
- Protects against file-based attacks
- Immutable container runtime

**Verification**:
```bash
kubectl exec <pod-name> -n <namespace> -- touch /test
# Should fail with "read-only file system"
```

### Dropped Linux Capabilities

**Implementation**:
- **Location**: `part-2-kubernetes/manifests/deployment.yaml`
- **Configuration**: `capabilities: drop: [ALL]`

**Security Benefit**:
- Removes all Linux capabilities
- Prevents privilege escalation attacks
- Follows principle of least privilege

**Verification**:
```bash
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].securityContext.capabilities}'
# Should show: {"drop":["ALL"]}
```

### Image Vulnerability Scanning

**Implementation**:
- **Location**: `.github/workflows/ci.yml`
- **Tool**: Trivy
- **Scans**: Filesystem and container images
- **Results**: Uploaded to GitHub Security tab (SARIF format)

**Configuration**:
- Filesystem scanning: Scans application dependencies
- Image scanning: Scans built Docker images
- Critical/High severity vulnerabilities reviewed
- Results integrated with GitHub Security tab

**Security Benefit**:
- Identifies known vulnerabilities in dependencies
- Prevents deployment of vulnerable images
- Continuous security monitoring

---

## Network Security

### Network Policies

**Implementation**:
- **Location**: `part-2-kubernetes/manifests/networkpolicy.yaml`
- **Policies**: Application and database network policies

**Application Network Policy**:
- Ingress: Allows traffic from ingress controller (any namespace)
- Egress: Allows traffic to RDS (port 5432), DNS (port 53), HTTPS (port 443)

**Database Network Policy**:
- Ingress: Only allows traffic from application pods
- Egress: Only allows DNS traffic

**Security Benefit**:
- Micro-segmentation of network traffic
- Defense-in-depth approach
- Limits lateral movement if compromised

**Verification**:
```bash
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy <policy-name> -n <namespace>
```

### TLS/SSL Encryption

**Implementation**:
- **Certificate Management**: cert-manager
- **Issuer**: Let's Encrypt (ClusterIssuer)
- **Location**: `part-2-kubernetes/manifests/clusterissuer.yaml`
- **Deployment**: Via Helm script (`deploy-helm-charts.sh`)

**Configuration**:
- ClusterIssuer: `letsencrypt-prod` (deployed and ready)
- Ingress configured with TLS
- Automatic certificate renewal
- HTTP to HTTPS redirect enforced

**Security Benefit**:
- Encrypts data in transit
- Prevents man-in-the-middle attacks
- Compliance with security standards

**Verification**:
```bash
kubectl get clusterissuer letsencrypt-prod
kubectl get certificate -n <namespace>
curl -v https://titanic-api.example.com/health
```

### Database Encryption

**Implementation**:
- **Location**: Part 5 (RDS Configuration)
- **Type**: Encryption at rest
- **Method**: AWS KMS managed keys

**Details**:
- RDS encryption enabled
- Encryption in transit (SSL/TLS)
- Connection string includes SSL parameters

**Security Benefit**:
- Protects data at rest
- Compliance requirements (GDPR, HIPAA, etc.)
- Defense against data breaches

---

## Secrets Management

### AWS Secrets Manager

**Implementation**:
- **Storage**: AWS Secrets Manager
- **Secrets**: RDS credentials, JWT secret key
- **Access**: Via External Secrets Operator (IRSA)

**Architecture**:
```
AWS Secrets Manager
    ↓ (IRSA Authentication)
External Secrets Operator
    ↓ (ClusterSecretStore)
ExternalSecret Resource
    ↓ (Sync)
Kubernetes Secret
    ↓ (Mount)
Application Pods
```

**Details**:
- Secrets stored: `titanic-api-prod-rds-credentials`
- ClusterSecretStore: `aws-secrets-manager` (cluster-wide)
- ExternalSecret syncs secrets to Kubernetes
- No secrets hardcoded in code or manifests

**Security Benefit**:
- Centralized secret management
- Automatic rotation support
- Audit trail in AWS CloudTrail
- No secrets in Git repository

**Verification**:
```bash
kubectl get clustersecretstore aws-secrets-manager
kubectl get externalsecret -n <namespace>
kubectl get secret <secret-name> -n <namespace>
```

### External Secrets Operator

**Implementation**:
- **Location**: Part 5 (Terraform) + Kubernetes manifests
- **Authentication**: IRSA (IAM Roles for Service Accounts)
- **Sync**: Automatic synchronization from AWS Secrets Manager

**Features**:
- No long-lived credentials
- Namespace isolation
- Automatic secret updates
- Helm ownership metadata support

---

## Access Control

### Kubernetes RBAC

**Implementation**:
- Service accounts with minimal permissions
- IRSA for AWS access
- Role-based access control

**Details**:
- External Secrets Operator uses IRSA
- No long-lived AWS credentials
- Service accounts scoped to namespaces

**Verification**:
```bash
kubectl get serviceaccounts -n <namespace>
kubectl get rolebindings,clusterrolebindings -n <namespace>
```

### IAM Policies (Least Privilege)

**Implementation**:
- **Location**: Part 5 (Terraform IAM module)
- **Principle**: Least privilege access

**Policies**:
- EKS cluster role: Minimal required policies
- Node role: Worker node minimal policy
- External Secrets: Secrets Manager read access only
- External DNS: Route53 management access
- Cert-Manager: Route53 DNS-01 challenge access

**Security Benefit**:
- Follows principle of least privilege
- Reduces attack surface
- Limits potential damage

### IRSA (IAM Roles for Service Accounts)

**Implementation**:
- OIDC provider configured for EKS
- Service accounts annotated with IAM role ARN
- No long-lived AWS credentials

**Service Accounts Using IRSA**:
- External Secrets Operator: AWS Secrets Manager access
- External DNS: Route53 management
- Cert-Manager: Route53 DNS-01 challenge
- Lab Controller: ECR pull access

**Verification**:
```bash
aws eks describe-cluster --name <cluster-name> --query "identity.oidc.issuer"
kubectl get serviceaccount external-secrets-operator -n external-secrets-system -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

### GitHub Environments

**Implementation**:
- **Location**: `.github/workflows/cd-prod.yml`
- **Features**: Production environment requires approval

**Details**:
- Deployment approval gates
- Branch restrictions
- Audit trail of deployments

**Security Benefit**:
- Prevents unauthorized deployments
- Manual review for production
- Deployment history tracking

---

## API Security

### Authentication

**Implementation**:
- **Location**: `titanic-api/src/auth.py`, `titanic-api/src/views/auth.py`
- **Method**: JWT (JSON Web Token) based authentication
- **Algorithm**: HS256
- **Expiration**: 1 hour (3600 seconds)

**Endpoints**:
- `POST /auth/login` - Login and get JWT token
- `GET /auth/me` - Get current user information (requires authentication)
- `POST /auth/verify` - Verify token validity

**Token Details**:
- Secret key stored in AWS Secrets Manager
- Token payload includes: user_id, username, roles, iat, exp
- Bearer token authentication: `Authorization: Bearer <token>`

**Security Features**:
- Token expiration (1 hour)
- Secret key from AWS Secrets Manager
- Token validation on every request

### Authorization

**Implementation**:
- **Location**: `titanic-api/src/auth.py`
- **Method**: Role-based access control (RBAC)

**Roles**:
- **User Role (`user`)**: Can read, create, and update people
- **Admin Role (`admin`)**: All user permissions plus delete operations

**Protected Endpoints**:
- All `/people` endpoints require authentication
- `DELETE /people/<uuid>` requires admin role
- `/health` and `/` remain public

**Decorators**:
- `@require_auth` - Authentication required
- `@require_role("admin")` - Role-based authorization

**Usage Example**:
```bash
# Login
TOKEN=$(curl -s -X POST https://titanic-api.example.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "user1", "password": "password123"}' \
  | jq -r '.token')

# Access protected endpoint
curl -X GET https://titanic-api.example.com/people \
  -H "Authorization: Bearer $TOKEN"
```

### Error Responses

**401 Unauthorized**:
- Missing token: "Missing or invalid Authorization header"
- Invalid token: "Token is expired or invalid"

**403 Forbidden**:
- Insufficient permissions: "Required roles: ['admin']"

---

## Compliance & Auditing

### Security Standards

**OWASP Top 10 Coverage**:
- A01: Broken Access Control - Network policies, RBAC
- A02: Cryptographic Failures - TLS/SSL, encryption at rest
- A03: Injection - SQLAlchemy ORM, parameterized queries
- A04: Insecure Design - Security by design, defense-in-depth
- A05: Security Misconfiguration - Hardened containers, least privilege
- A06: Vulnerable Components - Trivy scanning, dependency updates
- A07: Authentication Failures - JWT authentication implemented
- A08: Software Integrity - Image scanning, signed images
- A09: Security Logging - Structured logging, audit trails
- A10: SSRF - Network policies, egress restrictions

**CIS Docker Benchmark Compliance**:
- Non-root user
- Read-only root filesystem
- Dropped capabilities
- Image scanning
- Minimal base images

**Kubernetes Security Best Practices**:
- Pod security standards
- Network policies
- RBAC
- Secrets management
- Resource limits
- Security contexts

**AWS Well-Architected Framework**:
- Security Pillar: All security best practices implemented
- Operational Excellence: Monitoring and logging in place
- Reliability: Multi-AZ, backups, auto-scaling

### Audit Logging

**Implementation**:
- AWS CloudTrail: All API calls logged
- Kubernetes audit logs: API server, audit, authenticator, controller manager, scheduler
- Application logs: Structured JSON format
- EKS cluster logging: Enabled for all log types

**Log Retention**:
- CloudTrail: 90 days (configurable)
- Kubernetes logs: Configurable retention
- Application logs: Configurable per log group

**Security Benefit**:
- Complete audit trail
- Compliance requirements
- Incident investigation support

---

## Vulnerability Management

### Vulnerability Scanning

**Tools**:
- **Trivy**: Container and filesystem vulnerability scanning
- **Bandit**: Python security linter
- **GitHub Security**: Vulnerability tracking and reporting

**Scanning Process**:
1. Trivy filesystem scan on application dependencies
2. Trivy image scan on built Docker images
3. Bandit security linter on Python code
4. Results uploaded to GitHub Security tab (SARIF format)

**Remediation Process**:
1. Vulnerability identified by scanning tools
2. Security team notified via GitHub Security tab
3. Assess impact and exploitability
4. Update dependency or apply patch
5. Rebuild and redeploy
6. Verify fix

### Vulnerability Status

**Current Risk Level**: LOW

**Rationale**:
- All critical security controls are implemented
- Network segmentation limits attack surface
- Container hardening prevents many attack vectors
- API authentication and authorization implemented
- Infrastructure security is strong

**Known Limitations**:
- Metrics server not installed (HPA limitation, not security issue)
- Default storage class (acceptable for current use case)

### Continuous Improvement

**Regular Assessments**:
- Weekly: Review Trivy scan results
- Monthly: Dependency updates and security patches
- Quarterly: Full security assessment
- Annually: Penetration testing

---

## Security Monitoring

### Continuous Monitoring

**Vulnerability Scanning**:
- Trivy scans on every build
- GitHub Security tab for vulnerability tracking
- Automated alerts for critical vulnerabilities

**Infrastructure Monitoring**:
- Kubernetes audit logs
- AWS CloudTrail for IAM actions
- Application structured logging
- Prometheus metrics and Grafana dashboards

### Alerting

**Security Events**:
- Failed deployments trigger notifications
- Security scan failures block deployments
- Pod crash loops alert operators
- Certificate expiration warnings

**Monitoring Tools**:
- GitHub Security tab
- Prometheus alerts
- CloudWatch alarms
- Kubernetes events

---

## Incident Response

### Procedures

**Vulnerability Detected**:
1. Trivy scan identifies issue
2. Security team notified via GitHub Security tab
3. Assess severity (Critical/High/Medium/Low)
4. Patch or update dependency
5. Rebuild and redeploy
6. Verify fix
7. Document incident

**Secret Compromise**:
1. Rotate secret immediately in AWS Secrets Manager
2. Verify ExternalSecret syncs new value
3. Restart pods to pick up new secret
4. Review access logs for unauthorized access
5. Document incident and remediation

**Container Compromise**:
1. Network policies limit lateral movement
2. Read-only filesystem prevents persistence
3. Non-root user limits damage
4. Isolate affected pod
5. Review logs for attack vector
6. Terminate compromised pod
7. Review and patch vulnerability
8. Redeploy with fixes
9. Document incident

### Security Controls Matrix

| Control | Status | Location | Verification |
|---------|--------|----------|--------------|
| Non-root user | Complete | Dockerfile | `USER appuser` |
| Read-only rootfs | Complete | Deployment | `readOnlyRootFilesystem: true` |
| Dropped capabilities | Complete | Deployment | `capabilities: drop: [ALL]` |
| Image scanning | Complete | CI Pipeline | Trivy scanner |
| Network policies | Complete | NetworkPolicy | Pod-to-pod restrictions |
| TLS/SSL | Complete | Ingress + cert-manager | ClusterIssuer ready |
| Database encryption | Complete | RDS | Encryption at rest |
| Secret management | Complete | Secrets Manager + ESO | No hardcoded secrets |
| IRSA | Complete | IAM + Service Accounts | No long-lived credentials |
| RBAC | Complete | Kubernetes | Service account permissions |
| API Auth | Complete | Application | JWT authentication and authorization |

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [External Secrets Operator](https://external-secrets.io/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [JWT Best Practices](https://datatracker.ietf.org/doc/html/rfc8725)

---

**End of Documentation**
