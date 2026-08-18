# Cloud-Native EKS Platform Reference

An end-to-end reference implementation for running a containerized Python API on Amazon EKS. The project demonstrates infrastructure provisioning, secure workload identity, Kubernetes packaging, environment-aware delivery, observability, autoscaling, and disaster-recovery practices.

The workload uses a Titanic passenger API as a small application domain so the repository can focus on platform engineering decisions. It was originally created for a senior DevOps technical assessment and has since been generalized as a portfolio reference. It does not contain live credentials or production account identifiers.

## Architecture

```mermaid
flowchart LR
    Developer[Developer] --> GitHub[GitHub]
    GitHub --> CI[GitHub Actions CI]
    CI --> ECR[Amazon ECR]
    CD[Manual approved CD] --> EKS[Amazon EKS]
    ECR --> EKS
    Users[API clients] --> DNS[Route 53]
    DNS --> NLB[Network Load Balancer]
    NLB --> Ingress[NGINX Ingress]
    Ingress --> API[Titanic API pods]
    API --> RDS[(Amazon RDS PostgreSQL)]
    Secrets[AWS Secrets Manager] --> ESO[External Secrets Operator]
    ESO --> API
    API --> Metrics[Prometheus and Grafana]
```

Terraform provisions the AWS foundation. Helm packages the Kubernetes workload and GitHub Actions validates application and infrastructure changes. Deployment is manual and environment-protected so an image can be promoted deliberately through development, staging, and production.

## Engineering Highlights

- Multi-AZ VPC and private EKS worker networking managed with Terraform.
- Amazon EKS, ECR, encrypted RDS PostgreSQL, Route 53, and IAM roles for service accounts.
- External Secrets Operator integration with AWS Secrets Manager.
- Non-root container, read-only root filesystem, dropped Linux capabilities, and seccomp.
- Helm chart plus Kustomize and raw-manifest examples.
- Resource requests and limits, HPA, PodDisruptionBudget, NetworkPolicy, and probes.
- Prometheus metrics, Grafana dashboard, alerts, and structured application logging.
- GitHub Actions OIDC authentication with immutable image tags.
- Protected, manually triggered deployments with Helm atomic rollback.
- Documented backup, restore, incident, and recovery procedures.

## Repository Map

| Path | Purpose |
|---|---|
| `titanic-api/` | Flask API, PostgreSQL model, authentication, and observability |
| `part-1-containerization/` | Multi-stage container build and local Compose setup |
| `part-2-kubernetes/` | Helm, Kustomize, and Kubernetes deployment resources |
| `part-3-cicd/` | CI/CD design and operating guidance |
| `part-4-observability/` | Prometheus rules, ServiceMonitor, and Grafana dashboard |
| `part-5-iac/` | Modular Terraform for the AWS/EKS platform |
| `part-6-security/` | Security model and control mapping |
| `part-7-disaster-recovery/` | Backup, restore, and recovery procedures |

## CI/CD Flow

Pull requests and pushes run:

1. Python dependency installation, blocking-error linting, and application tests.
2. Terraform formatting, initialization without remote state, and validation.
3. Trivy filesystem scanning with SARIF upload to GitHub code scanning.

Image publishing is intentionally disabled until the repository variable `ENABLE_IMAGE_PUSH` is set to `true`. When enabled, CI assumes an AWS role through OIDC and publishes an image tagged with the full Git commit SHA.

The `CD - Deploy to EKS` workflow requires an immutable image tag and a target environment. GitHub environment protection rules can require approval for staging or production, and Helm's `--atomic` option rolls back a failed release.

## Local Application Test

Prerequisites: Python 3.11 and PostgreSQL 15.

```bash
cd titanic-api
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt pytest
export DATABASE_URL=postgresql+psycopg2://titanic_user:test_password@localhost:5432/titanic_db
pytest tests -v
```

On Windows PowerShell, activate the environment with `.venv\Scripts\Activate.ps1` and set the variable with `$env:DATABASE_URL=...`.

## Infrastructure Validation

```bash
cd part-5-iac/terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Before applying the infrastructure, replace the example backend names and review every environment-specific value. Terraform state storage must exist before remote-backend initialization.

## Deployment Configuration

Configure these GitHub repository or environment values before enabling delivery:

| Setting | Type | Purpose |
|---|---|---|
| `AWS_ROLE_ARN` | Secret | Least-privilege AWS role trusted through GitHub OIDC |
| `AWS_REGION` | Variable | AWS deployment region |
| `ECR_REPOSITORY_URL` | Variable | Full ECR repository URL |
| `EKS_CLUSTER_NAME` | Variable | Target EKS cluster for each GitHub environment |
| `APP_SECRET_NAME` | Variable | Environment-specific AWS Secrets Manager secret name |
| `ENABLE_IMAGE_PUSH` | Variable | Explicit opt-in for publishing images |

Application credentials are not passed through workflow inputs or committed values. Use External Secrets Operator with AWS Secrets Manager, or create the Kubernetes Secret named by `secrets.existingSecret` before installation.

## Design Trade-offs

- A single NAT gateway can reduce non-production cost; production should consider one per availability zone.
- The repository includes Helm, Kustomize, and raw manifests to demonstrate alternative packaging methods. Helm is the supported CD path.
- EKS and RDS create meaningful AWS cost. Review the Terraform plan and destroy demonstration environments when no longer required.
- This repository is a reference implementation, not a claim that the example endpoints are currently running.

Detailed implementation notes remain available in [SOLUTION.md](SOLUTION.md) and the documentation directories listed above.
