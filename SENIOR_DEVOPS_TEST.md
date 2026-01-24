# Mid/Senior DevOps Engineer Technical Assessment

**Submission Method:** Git repository

## Overview

This assessment evaluates your ability to take a basic application and implement production-ready DevOps practices. You'll be assessed on containerization, orchestration, CI/CD, monitoring, security, and infrastructure-as-code skills.

## Current State

We've provided an API, built with the Python programming language.

* Go to **https://github.com/PipeOpsHQ/titanic-api**.
* Copy the Python implementation of the API into a new repository. Feel free to make any changes to the code you think are necessary, but don't waste your time!

The Titanic API is a basic Flask application with:
- A PostgreSQL database
- RESTful endpoints for passenger data
- Manual setup instructions
- No container orchestration
- No CI/CD pipeline
- No monitoring or observability
- No automated testing infrastructure

## Your Mission

Transform this basic application into a production-ready, cloud-native service following DevOps best practices.

---

## Part 1: Containerization & Local Development

### Requirements

1. **Multi-stage Dockerfile**
   - Create an optimized multi-stage build
   - Use non-root user for security
   - Implement proper layer caching
   - Include health checks
   - Target size: < 200MB for production image

2. **Docker Compose Setup**
   - Multi-container orchestration (app + database)
   - Proper networking and service dependencies
   - Volume management for data persistence
   - Health checks and restart policies
   - Environment variable management

3. **Development Workflow**
   - Create separate dev and prod configurations
   - Hot-reload for development
   - Database initialization automation

### Evaluation Criteria
- Image optimization and security
- Development experience (how easy is it to run locally?)
- Documentation quality

---

## Part 2: Kubernetes Deployment

### Requirements

1. **Core Manifests**
   - Deployment with proper resource limits and requests
   - Service (ClusterIP and LoadBalancer/Ingress)
   - ConfigMap for non-sensitive configuration
   - Secret for sensitive data
   - PersistentVolumeClaim for database

2. **Advanced Kubernetes Features**
   - Horizontal Pod Autoscaler (HPA) based on CPU/memory
   - Liveness and readiness probes
   - Pod Disruption Budget
   - Network Policy (restrict database access)
   - Resource quotas and limits

3. **Deployment Strategy**
   - Implement rolling update strategy
   - Configure proper rollback mechanism
   - Zero-downtime deployment approach

### Bonus Points
- Helm chart implementation
- Kustomize overlays for multi-environment support
- Service mesh integration (Istio/Linkerd)

### Evaluation Criteria
- Production readiness
- Security best practices
- Scalability considerations
- High availability design

---

## Part 3: CI/CD Pipeline

### Requirements

Create a complete CI/CD pipeline using **GitHub Actions** (or GitLab CI if preferred).

1. **Continuous Integration**
   - Automated testing (unit tests, linting)
   - Code quality checks (coverage thresholds)
   - Security scanning (container image vulnerabilities)
   - Build and push Docker image to registry

2. **Continuous Deployment**
   - Automated deployment to Kubernetes
   - Multi-environment strategy (dev/staging/production)
   - Deployment approval gates for production
   - Automated rollback on failure

3. **Pipeline Best Practices**
   - Semantic versioning for images
   - Caching for faster builds
   - Parallel job execution
   - Secrets management
   - Deployment notifications (Slack/Email)

### Evaluation Criteria
- Pipeline efficiency
- Error handling and recovery
- Security practices
- Documentation

---

## Part 4: Observability & Monitoring

### Requirements

1. **Application Instrumentation**
   - Add structured logging (JSON format)
   - Implement Prometheus metrics endpoint
   - Add distributed tracing (OpenTelemetry)
   - Custom business metrics (API requests, response times)

2. **Monitoring Stack**
   - Prometheus configuration for scraping
   - Grafana dashboard (minimum 3 panels):
     - Request rate and latency
     - Error rate
     - Resource utilization (CPU/Memory)
   - Alert rules for critical scenarios

3. **Logging Strategy**
   - Centralized logging (ELK/Loki/CloudWatch)
   - Log aggregation from all pods
   - Structured logging format
   - Log retention policy

### Bonus Points
- APM integration (DataDog/New Relic)
- Custom SLI/SLO definitions
- Automated incident response

### Evaluation Criteria
- Observability maturity
- Alert quality (actionable, not noisy)
- Dashboard usefulness

---

## Part 5: Infrastructure as Code

### Requirements

Choose ONE cloud provider and implement:

1. **Terraform/Pulumi/CloudFormation**
   - VPC/Network configuration
   - Kubernetes cluster (EKS/AKS/GKE)
   - RDS/Cloud SQL for database
   - Load balancer configuration
   - IAM roles and policies

2. **Infrastructure Best Practices**
   - Remote state management
   - Environment separation (workspaces/separate states)
   - Secrets management (AWS Secrets Manager/Vault)
   - Cost optimization considerations
   - Disaster recovery plan

3. **Documentation**
   - Architecture diagram
   - Deployment runbook
   - Cost estimation
   - Security controls

### Evaluation Criteria
- Code organization and modularity
- Security posture
- Cost optimization
- Scalability design

---

## Part 6: Security & Compliance

### Requirements

1. **Container Security**
   - Implement image scanning in CI
   - Non-root user in containers
   - Read-only root filesystem
   - Dropped Linux capabilities
   - Secret management (never hardcoded)

2. **Network Security**
   - Network policies to restrict pod communication
   - TLS/SSL for all endpoints
   - Database connection encryption
   - API authentication/authorization

3. **Compliance Documentation**
   - Document security controls
   - Create security checklist
   - Vulnerability assessment report

### Evaluation Criteria
- Defense-in-depth approach
- Secrets management
- Compliance awareness

---

## Part 7: Disaster Recovery & Backup

### Requirements

1. **Backup Strategy**
   - Database backup automation
   - Backup retention policy
   - Point-in-time recovery plan
   - Configuration backup

2. **Disaster Recovery**
   - RTO (Recovery Time Objective) definition
   - RPO (Recovery Point Objective) definition
   - Failover procedure documentation
   - Multi-region/AZ strategy

### Evaluation Criteria
- Business continuity planning
- Automation level
- Documentation clarity

---

## Deliverables

### Required

1. **Code Repository**
   - All configuration files (Dockerfiles, manifests, IaC)
   - CI/CD pipeline configuration
   - Well-organized directory structure
   - `.gitignore` properly configured

2. **Documentation** (`SOLUTION.md`)
   - Architecture diagram
   - Setup instructions
   - Design decisions and trade-offs
   - Known limitations and future improvements
   - Estimated cloud costs (monthly)

3. **Demo Instructions**
   - How to run locally
   - How to deploy to Kubernetes
   - How to trigger CI/CD pipeline
   - How to access monitoring dashboards

### Optional Bonus

- Video walkthrough
- Performance testing results (load testing)
- Cost optimization report
- Security audit report

---


## Assessment Guidelines

### What We're Looking For

**Production-Ready Mindset**
- It works reliably, not just "works on my machine"
- Proper error handling and graceful degradation
- Security and compliance built-in, not bolted on

**Automation First**
- Minimal manual intervention required
- Self-healing and auto-scaling capabilities
- Infrastructure and deployment fully automated

**Operational Excellence**
- Comprehensive monitoring and alerting
- Clear runbooks and documentation
- Disaster recovery and backup strategies

**Cost Consciousness**
- Right-sized resources
- Cost optimization strategies documented
- Understanding of cloud pricing models

### What Will Get You Bonus Points

- **Innovation:** Novel approaches to common problems
- **Scalability:** Design that handles 10x growth
- **Developer Experience:** Tools and automation that make developers productive
- **Teaching:** Explain complex concepts clearly in documentation

### Red Flags

- Hardcoded secrets or credentials  
- No resource limits in Kubernetes  
- Running containers as root  
- No monitoring or logging  
- Single point of failure in design  
- Poor documentation or no documentation  
- Ignoring security best practices  

---


## Questions?

During the assessment, you may:
- Use Google, Stack Overflow, documentation
- Use AI assistants (ChatGPT, GitHub Copilot)
- Reference your previous work

---

## Submission

1. Create a public GitHub repository (or provide access to private repo)
2. Reply to our email with a link to your new private repository.

---

## Good Luck!

We're excited to see how you approach these challenges. Remember: perfect execution is less important than demonstrating senior-level thinking, security awareness, and production readiness.

Show us how you would build this for a real production environment where uptime, security, and developer experience matter.
