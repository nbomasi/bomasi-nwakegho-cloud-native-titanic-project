# Cloud-Native Titanic API

A production-ready cloud-native implementation of the Titanic API, demonstrating comprehensive DevOps practices including containerization, Kubernetes orchestration, CI/CD pipelines, observability, security controls, infrastructure as code, and disaster recovery strategies.

## Quick Links

- **[Complete Solution Documentation](./SOLUTION.md)** - Comprehensive overview of the entire project
- **[Technical Assessment Requirements](./SENIOR_DEVOPS_TEST.md)** - Original requirements

## Documentation

- [Part 1: Containerization](./part-1-containerization/CONTAINERIZATION.md)
- [Part 2: Kubernetes Deployment](./part-2-kubernetes/KUBERNETES.md)
- [Part 3: CI/CD Pipeline](./part-3-cicd/CICD.md)
- [Part 4: Observability & Monitoring](./part-4-observability/OBSERVABILITY.md)
- [Part 5: Infrastructure as Code](./part-5-iac/INFRASTRUCTURE.md)
- [Part 6: Security & Compliance](./part-6-security/SECURITY.md)
- [Part 7: Disaster Recovery & Backup](./part-7-disaster-recovery/DISASTER_RECOVERY.md)

## Quick Start

```bash
# Provision Infrastructure
cd part-5-iac/terraform
terraform workspace select prod
terraform init && terraform apply

# Deploy Application
./scripts/deploy-manifests.sh titanic-api-prod latest production
```

For detailed instructions, see [SOLUTION.md](./SOLUTION.md).

## Demo Videos

- [Containerization](https://youtu.be/VvFYteTnp2k) | [Infrastructure](https://youtu.be/y5nXcPFyeHg) | [CI Pipeline](https://youtu.be/8yxwphsIloU) | [Deployment](https://youtu.be/o1Qrchonjgw) | [Grafana Dashboard](https://youtu.be/lKeKEZORMFQ)

## Technology Stack

Docker • Kubernetes (EKS) • GitHub Actions • Terraform • Prometheus • Grafana • PostgreSQL (RDS)

---

**Status:** ✅ Production Ready | **Last Updated:** January 2025

For complete documentation, see [SOLUTION.md](./SOLUTION.md).
