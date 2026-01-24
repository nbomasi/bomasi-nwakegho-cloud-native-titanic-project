# Part 3: CI/CD Pipeline

## Executive Summary

This document describes the complete CI/CD pipeline implementation for the Titanic API project using GitHub Actions. The pipeline implements industry best practices for continuous integration and continuous deployment, including automated testing, security scanning, multi-environment deployments, and production approval gates. All requirements for Part 3 of the technical assessment have been met, including automated testing with coverage thresholds, security scanning, Docker image building and pushing to Amazon ECR, automated Kubernetes deployments, multi-environment strategy, deployment approval gates, and automated rollback mechanisms.

## Table of Contents

1. [Requirements Overview](#requirements-overview)
2. [Architecture](#architecture)
3. [Pipeline Workflows](#pipeline-workflows)
4. [Continuous Integration](#continuous-integration)
5. [Continuous Deployment](#continuous-deployment)
6. [Configuration](#configuration)
7. [Setting Up AWS IAM Roles and GitHub Secrets](#setting-up-aws-iam-roles-and-github-secrets)
8. [Usage](#usage)
9. [Best Practices Implemented](#best-practices-implemented)
10. [Security Features](#security-features)
11. [Troubleshooting](#troubleshooting)
12. [Compliance with Requirements](#compliance-with-requirements)
13. [Known Limitations](#known-limitations)
14. [References](#references)
15. [Conclusion](#conclusion)

## Requirements Overview

### 1. Continuous Integration

**Requirement:** Automated testing (unit tests, linting), code quality checks (coverage thresholds), security scanning (container image vulnerabilities), and build and push Docker image to registry.

**Implementation Status:** Complete

- Automated testing with pytest and coverage reporting (70% threshold)
- Code quality checks: flake8, black, isort, mypy
- Security scanning: Trivy (filesystem and container images), Bandit (Python security)
- Docker image building and pushing to Amazon ECR
- Multi-platform builds (amd64, arm64)
- Build caching for faster pipeline execution

### 2. Continuous Deployment

**Requirement:** Automated deployment to Kubernetes, multi-environment strategy (dev/staging/production), deployment approval gates for production, and automated rollback on failure.

**Implementation Status:** Complete

- Automated deployment to Kubernetes using Helm
- Multi-environment support: development, staging, production
- Production approval gates via GitHub Environments
- Automatic rollback on deployment failure
- Health checks and smoke tests after deployment
- Deployment verification and monitoring

### 3. Pipeline Best Practices

**Requirement:** Semantic versioning for images, caching for faster builds, parallel job execution, secrets management, and deployment notifications.

**Implementation Status:** Complete

- Semantic versioning with automatic tag generation
- Docker layer caching and GitHub Actions cache
- Parallel job execution (test, security scan, build)
- Secrets management via GitHub Secrets and AWS IRSA
- Deployment notifications (ready for Slack/Email integration)
- Image tagging strategy for different branches

## Architecture

### Pipeline Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Code Push/PR                               │
│              (main, develop, feature branches)                │
└──────────────────────┬────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              CI Pipeline (ci.yml)                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Test Job  │  │ Security Job │  │  Build Job    │      │
│  │  - pytest   │  │  - Trivy     │  │  - Docker     │      │
│  │  - linting  │  │  - Bandit    │  │  - Push ECR   │      │
│  │  - coverage │  │              │  │  - Scan image │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└──────────────────────┬────────────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
         ▼             ▼             ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│  Dev Deploy  │ │Staging Deploy│ │ Prod Deploy  │
│  (develop)   │ │   (main)     │ │ (approval)   │
│              │ │              │ │              │
│  Auto        │ │  Auto         │ │  Manual      │
│  Deploy      │ │  Deploy       │ │  Approval    │
└──────────────┘ └──────────────┘ └──────────────┘
         │             │             │
         └─────────────┼─────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │   EKS Clusters       │
            │  (dev/staging/prod)  │
            └──────────────────────┘
```

### Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                        │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │         GitHub Actions Workflows                      │ │
│  │  - ci.yml (CI Pipeline)                               │ │
│  │  - cd-dev.yml (Development Deployment)               │ │
│  │  - cd-staging.yml (Staging Deployment)                │ │
│  │  - cd-prod.yml (Production Deployment)                │ │
│  │  - version.yml (Semantic Versioning)                  │ │
│  └──────────────────────┬─────────────────────────────────┘ │
└─────────────────────────┼───────────────────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  Amazon ECR  │  │  AWS EKS     │  │  AWS IAM     │
│  (Container  │  │  (Kubernetes │  │  (IRSA)      │
│   Registry) │  │   Clusters)  │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
```

## Pipeline Workflows

### Workflow Overview

The CI/CD pipeline consists of five main workflows:

1. **CI Pipeline** (`ci.yml`) - Continuous Integration
2. **CD - Development** (`cd-dev.yml`) - Development deployments
3. **CD - Staging** (`cd-staging.yml`) - Staging deployments
4. **CD - Production** (`cd-prod.yml`) - Production deployments
5. **Semantic Versioning** (`version.yml`) - Automatic version tagging

### Workflow File Structure

```
.github/workflows/
├── ci.yml              # Continuous Integration pipeline
├── cd-dev.yml          # Development deployment
├── cd-staging.yml      # Staging deployment
├── cd-prod.yml         # Production deployment
└── version.yml         # Semantic versioning
```

## Continuous Integration

### CI Pipeline Overview

**Workflow File:** `.github/workflows/ci.yml`

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Changes to `titanic-api/` or `part-1-containerization/` directories

**Jobs:**

#### 1. Test Job

**Purpose:** Run automated tests and code quality checks

**Steps:**
1. Checkout code
2. Set up Python 3.11 environment with pip caching
3. Start PostgreSQL service container
4. Install dependencies (including test tools)
5. Run linters:
   - `flake8` - Python style guide enforcement
   - `black` - Code formatting check
   - `isort` - Import sorting verification
   - `mypy` - Static type checking
6. Run unit tests with pytest
7. Generate coverage reports (XML, HTML, terminal)
8. Upload coverage to Codecov
9. Verify coverage threshold (70% minimum)

**Coverage Threshold:** 70% (configurable)

#### 2. Security Scan Job

**Purpose:** Identify security vulnerabilities in code and dependencies

**Steps:**
1. Checkout code
2. Run Trivy filesystem scan
3. Upload results to GitHub Security tab (SARIF format)
4. Run Bandit security linter for Python
5. Upload Bandit report as artifact

**Tools:**
- **Trivy:** Comprehensive vulnerability scanner
- **Bandit:** Python security linter

#### 3. Build Job

**Purpose:** Build and push Docker images to Amazon ECR

**Dependencies:** Test and Security Scan jobs must pass

**Steps:**
1. Configure AWS credentials (IRSA)
2. Set up Docker Buildx
3. Login to Amazon ECR
4. Create ECR repository if it doesn't exist
5. Extract metadata and generate tags:
   - Branch-based tags (`main`, `develop`)
   - Semantic version tags (`v1.2.3`)
   - SHA-based tags (`main-abc12345`)
   - Latest tag (for main branch only)
6. Build multi-platform image (amd64, arm64)
7. Push to ECR with caching
8. Scan image with Trivy
9. Upload scan results to GitHub Security
10. Generate and save image metadata

**Image Tagging Strategy:**
- `main` branch → `latest`, `main-<sha>`, semantic versions
- `develop` branch → `develop-<sha>`
- Feature branches → `<branch>-<sha>`
- Pull requests → `pr-<number>`

**ECR Configuration:**
- Registry: `<aws-account-id>.dkr.ecr.<region>.amazonaws.com`
- Repository: `titanic-api`
- Auto-created if missing

### CI Pipeline Features

- **Parallel Execution:** Test, security scan, and build jobs run in parallel (where possible)
- **Conditional Execution:** Build job only runs on push (not PRs)
- **Caching:** Docker layer caching and pip package caching
- **Multi-platform:** Builds for both amd64 and arm64 architectures
- **Security:** Image scanning before push, results in GitHub Security tab

## Continuous Deployment

### Development Deployment

**Workflow File:** `.github/workflows/cd-dev.yml`

**Triggers:**
- Push to `develop` branch
- Manual workflow dispatch

**Environment:** `development` (no protection rules)

**Features:**
- Automatic deployment on push to develop
- Single replica for cost efficiency
- No autoscaling
- Quick smoke tests
- Automatic rollback on failure

**Deployment Steps:**
1. Configure AWS credentials (IRSA)
2. Set up kubectl
3. Connect to EKS cluster
4. Determine image tag (from branch or manual input)
5. Deploy using Helm
6. Verify deployment
7. Run smoke tests

**Configuration:**
- Namespace: `titanic-api-dev`
- Replicas: 1
- Autoscaling: Disabled
- Ingress: Enabled

### Staging Deployment

**Workflow File:** `.github/workflows/cd-staging.yml`

**Triggers:**
- Push to `main` branch
- Manual workflow dispatch

**Environment:** `staging` (optional reviewers)

**Features:**
- Pre-deployment validation (Helm lint)
- Production-like configuration
- 2 replicas minimum
- Autoscaling enabled
- Integration tests
- Automatic rollback on failure

**Deployment Steps:**
1. Configure AWS credentials
2. Set up kubectl
3. Connect to EKS cluster
4. Run Helm lint validation
5. Deploy using Helm
6. Verify deployment
7. Run integration tests

**Configuration:**
- Namespace: `titanic-api-staging`
- Replicas: 2 (min)
- Autoscaling: Enabled (2-10 replicas)
- Ingress: Enabled

### Production Deployment

**Workflow File:** `.github/workflows/cd-prod.yml`

**Triggers:**
1. **Automatic (after staging):** Successful completion of Staging Deployment workflow
   - Still requires manual approval before actual deployment
   - Ensures staging has been tested before production
2. **Manual:** Workflow dispatch (for hotfixes or specific version deployments)
   - Requires image tag input
   - Optional skip approval for admins

**Environment:** `production` (with approval gates)

**Features:**
- **Approval gates** - Requires manual approval before deployment (both trigger methods)
- Pre-deployment validation
- Deployment backup creation
- Atomic deployments (rollback on failure)
- Extended health monitoring
- Production smoke tests
- Automatic rollback on failure
- Post-deployment verification

**Deployment Steps:**
1. Pre-deployment checks
2. Verify image exists in ECR
3. **Approval gate** (manual review) - Required for both automatic and manual triggers
4. Configure AWS credentials
5. Create deployment backup
6. Deploy using Helm (atomic)
7. Verify deployment
8. Run production smoke tests
9. Monitor health for 2 minutes
10. Post-deployment verification

**Approval Process:**
- Production deployments **always** require manual approval (regardless of trigger method)
- Approval can be granted via GitHub Environments UI
- Skip approval option available for admins (only via manual workflow_dispatch with `skip_approval: true`)

**Why Two Trigger Methods?**
- **Automatic trigger (workflow_run):** Promotes best practice of deploying to production only after successful staging deployment
- **Manual trigger (workflow_dispatch):** Allows flexibility for:
  - Hotfix deployments
  - Deploying specific versions
  - Emergency deployments
  - Re-deploying previous versions

**Configuration:**
- Namespace: `titanic-api-prod`
- Replicas: 2 (min)
- Autoscaling: Enabled (2-10 replicas)
- Pod Disruption Budget: Enabled
- Ingress: Enabled with TLS

### Semantic Versioning

**Workflow File:** `.github/workflows/version.yml`

**Triggers:**
- Push to `main` branch

**Purpose:** Automatically create version tags and GitHub releases

**Version Bump Logic:**
- **Minor bump:** If commits contain `feat:` or `feature:`
- **Patch bump:** If commits contain `fix:`, `bugfix:`, or `hotfix:`
- **Default:** Patch bump

**Steps:**
1. Checkout code with full history
2. Generate version based on commit messages
3. Create Git tag
4. Create GitHub Release

## Configuration

### Required GitHub Secrets

#### AWS Configuration
- `AWS_ACCOUNT_ID` - AWS account ID (for ECR registry URL, e.g., `456128143446`)
- `AWS_ACCESS_KEY_ID` - AWS access key ID for CI pipeline (needs ECR push/pull permissions)
- `AWS_SECRET_ACCESS_KEY` - AWS secret access key for CI pipeline
- `ECR_REPOSITORY_URL` - Full ECR repository URL (recommended: `456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo`)
- `AWS_REGION` - AWS region (default: eu-west-2)

**Note:** The CI pipeline uses AWS access keys stored in GitHub Secrets. It's recommended to set `ECR_REPOSITORY_URL` as a single secret containing the full repository URL for cleaner configuration. Ensure the IAM user has the required permissions listed below, especially **list permissions** for ECR operations.

#### EKS Cluster Names
- `EKS_CLUSTER_NAME_DEV` - Development EKS cluster name
- `EKS_CLUSTER_NAME_STAGING` - Staging EKS cluster name
- `EKS_CLUSTER_NAME_PROD` - Production EKS cluster name

#### Optional Notifications
- `SLACK_WEBHOOK_URL` - Slack webhook for deployment notifications
- `EMAIL_NOTIFICATION` - Email address for deployment notifications

### GitHub Environments

Configure the following environments in GitHub repository settings:

1. **development**
   - No protection rules
   - Used for automatic dev deployments

2. **staging**
   - Optional: Required reviewers
   - Used for staging deployments

3. **production**
   - **Required reviewers:** 1-2 approvers
   - **Deployment branches:** Only `main` branch
   - Used for production deployments with approval gates

### Container Registry

The pipeline uses **Amazon Elastic Container Registry (ECR)**:
- Full Repository URL: `456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo`
- Full image path: `456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo:<tag>`
- Authentication: AWS IAM credentials via GitHub Secrets
- Configuration: Set `ECR_REPOSITORY_URL` secret with the full repository URL (recommended approach)
- ECR repository is automatically created if it doesn't exist

### IAM User Permissions Required

**CI IAM User (for `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`):**

The IAM user used for CI pipeline needs the following ECR permissions:

**Required ECR Permissions:**
- `ecr:GetAuthorizationToken` - Get ECR login token
- `ecr:BatchCheckLayerAvailability` - Check layer availability
- `ecr:GetDownloadUrlForLayer` - Get download URLs
- `ecr:BatchGetImage` - Pull images
- `ecr:PutImage` - Push images
- `ecr:InitiateLayerUpload` - Start layer upload
- `ecr:UploadLayerPart` - Upload layer parts
- `ecr:CompleteLayerUpload` - Complete layer upload
- `ecr:DescribeRepositories` - **List repositories** (required for ECR operations)
- `ecr:ListImages` - **List images in repository** (required for ECR operations)
- `ecr:DescribeImages` - Describe image details
- `ecr:CreateRepository` - Create repository if it doesn't exist (optional, for auto-creation)

**Important:** Ensure the IAM user has **list permissions** (`ecr:ListImages`, `ecr:DescribeRepositories`) as these are required for ECR operations and image verification.

**Example IAM Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:CreateRepository"
      ],
      "Resource": "*"
    }
  ]
}
```

**Deployment Roles (`AWS_ROLE_ARN_DEV/STAGING/PROD`):**
- EKS cluster access (`eks:DescribeCluster`, `eks:ListClusters`)
- ECR read access (`ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`)
- Kubernetes API access (via EKS cluster)

## Setting Up AWS Credentials and GitHub Secrets

This section provides step-by-step instructions for configuring AWS credentials and GitHub secrets required for the CI/CD pipeline.

**Note:** This guide uses AWS access keys stored in GitHub Secrets. For production environments, consider using IAM roles with OIDC for enhanced security.

### Step 1: Get Your AWS Account ID

**Method 1: AWS CLI**
```bash
aws sts get-caller-identity --query Account --output text
```

**Method 2: AWS Console**
1. Log in to AWS Management Console
2. Click on your username in the top-right corner
3. Your Account ID is displayed in the dropdown menu

**Method 3: From Existing Resources**
```bash
# From any existing resource ARN
aws iam get-user --query 'User.Arn' --output text
# Output format: arn:aws:iam::<ACCOUNT_ID>:user/<username>
```

### Step 2: Create IAM User for CI Pipeline

Create an IAM user with ECR permissions for the CI pipeline.

**2.1 Create IAM User**

```bash
aws iam create-user \
  --user-name github-actions-ci \
  --tags Key=Purpose,Value=CI/CD Key=Environment,Value=All
```

**2.2 Create and Attach ECR Policy**

Create a file `ecr-ci-policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:CreateRepository"
      ],
      "Resource": "*"
    }
  ]
}
```

Attach the policy:
```bash
aws iam put-user-policy \
  --user-name github-actions-ci \
  --policy-name ECRFullAccess \
  --policy-document file://ecr-ci-policy.json
```

**Important:** Ensure the policy includes `ecr:ListImages` and `ecr:DescribeRepositories` permissions as these are required for ECR operations.

**2.3 Create Access Keys**

```bash
aws iam create-access-key --user-name github-actions-ci
```

Save the output:
- `AccessKeyId` → Will be used for `AWS_ACCESS_KEY_ID` secret
- `SecretAccessKey` → Will be used for `AWS_SECRET_ACCESS_KEY` secret

**Security Note:** Store these credentials securely. Never commit them to version control.

### Step 3: (Optional) Create IAM Roles for Deployment Pipelines

If you're using IAM roles for CD pipelines (dev/staging/prod), follow these steps:
      {
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:CreateRepository"
        ],
        "Resource": "*"
      }
    ]
  }'
```

**3.4 Get Role ARN**

```bash
aws iam get-role --role-name GitHubActions-CI-Role \
  --query 'Role.Arn' --output text
```

Save this ARN for GitHub secret `AWS_ROLE_ARN_CI`.

### Step 4: Create IAM Roles for Deployments

Each environment (dev/staging/prod) needs an IAM role with EKS and ECR access.

**4.1 Create Trust Policy for Deployment Roles**

Create `deployment-trust-policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<GITHUB_OWNER>/<GITHUB_REPO>:*"
        }
      }
    }
  ]
}
```

**4.2 Create Deployment Roles**

```bash
# Development role
aws iam create-role \
  --role-name GitHubActions-Deploy-Dev \
  --assume-role-policy-document file://deployment-trust-policy.json \
  --description "IAM role for GitHub Actions dev deployments"

# Staging role
aws iam create-role \
  --role-name GitHubActions-Deploy-Staging \
  --assume-role-policy-document file://deployment-trust-policy.json \
  --description "IAM role for GitHub Actions staging deployments"

# Production role
aws iam create-role \
  --role-name GitHubActions-Deploy-Prod \
  --assume-role-policy-document file://deployment-trust-policy.json \
  --description "IAM role for GitHub Actions production deployments"
```

**4.3 Attach Permissions to Deployment Roles**

```bash
# Attach EKS access policy
for ROLE in GitHubActions-Deploy-Dev GitHubActions-Deploy-Staging GitHubActions-Deploy-Prod; do
  aws iam attach-role-policy \
    --role-name $ROLE \
    --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
  
  # Attach ECR read-only policy
  aws iam attach-role-policy \
    --role-name $ROLE \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
done
```

**4.4 Create Custom Policy for EKS Cluster Access**

Create `eks-access-policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
```

```bash
# Create and attach policy for each deployment role
for ROLE in GitHubActions-Deploy-Dev GitHubActions-Deploy-Staging GitHubActions-Deploy-Prod; do
  aws iam put-role-policy \
    --role-name $ROLE \
    --policy-name EKSAccessPolicy \
    --policy-document file://eks-access-policy.json
done
```

**4.5 Get Role ARNs**

```bash
# Get all deployment role ARNs
for ROLE in GitHubActions-Deploy-Dev GitHubActions-Deploy-Staging GitHubActions-Deploy-Prod; do
  echo "$ROLE:"
  aws iam get-role --role-name $ROLE --query 'Role.Arn' --output text
done
```

Save these ARNs for GitHub secrets:
- `AWS_ROLE_ARN_DEV`
- `AWS_ROLE_ARN_STAGING`
- `AWS_ROLE_ARN_PROD`

### Step 5: Configure GitHub Secrets

**5.1 Navigate to Repository Settings**

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

**5.2 Add Required Secrets**

Add each secret with the following values:

| Secret Name | Value | Example |
|------------|-------|---------|
| `AWS_ACCOUNT_ID` | Your AWS account ID | `456128143446` |
| `AWS_ACCESS_KEY_ID` | AWS access key ID (from Step 2.3) | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key (from Step 2.3) | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `ECR_REPOSITORY_URL` | Full ECR repository URL (recommended) | `456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo` |
| `AWS_REGION` | AWS region | `eu-west-2` |
| `EKS_CLUSTER_NAME_DEV` | Development EKS cluster name | `titanic-api-eks-dev` |
| `EKS_CLUSTER_NAME_STAGING` | Staging EKS cluster name | `titanic-api-eks-staging` |
| `EKS_CLUSTER_NAME_PROD` | Production EKS cluster name | `titanic-api-eks-prod` |

**Note:** The CI pipeline uses `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` for authentication. It's **recommended** to set `ECR_REPOSITORY_URL` as a single secret containing the full repository URL (e.g., `456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo`) for cleaner and more maintainable configuration. Ensure the IAM user has the required ECR permissions, especially **list permissions** (`ecr:ListImages`, `ecr:DescribeRepositories`).

**5.3 Verify Secrets**

You can verify secrets are set (but not view values) in the GitHub UI:
- Settings → Secrets and variables → Actions
- All secrets should be listed

### Step 6: Verify Configuration

**6.1 Test CI Pipeline**

```bash
# Trigger CI pipeline by pushing code or creating a PR
git push origin develop

# Check GitHub Actions tab for workflow run
# Verify it can authenticate and push to ECR
```

**6.2 Verify ECR Repository**

```bash
# Check if repository was created (extract repo name from URL)
REPO_URL="456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo"
REPO_NAME=$(echo "$REPO_URL" | cut -d'/' -f2-)
aws ecr describe-repositories --repository-names "$REPO_NAME" --region eu-west-2

# List images in repository
aws ecr list-images --repository-name "$REPO_NAME" --region eu-west-2
```

**6.3 Test Deployment**

```bash
# Manually trigger deployment workflow
gh workflow run "CD - Development Deployment" --ref develop

# Monitor in GitHub Actions tab
# Verify it can authenticate and deploy to EKS
```

## Usage

### Triggering Deployments

#### Automatic Deployments
- **Development:** Push to `develop` branch → automatic deployment
- **Staging:** Push to `main` branch → automatic deployment
- **Production:** After successful staging deployment → triggers workflow, but **still requires manual approval**

#### Manual Deployments

All environments support manual triggering via GitHub Actions UI or CLI:

**Development:**
```bash
gh workflow run "CD - Development Deployment" \
  --ref develop \
  -f image_tag=develop-abc12345
```

**Staging:**
```bash
gh workflow run "CD - Staging Deployment" \
  --ref main \
  -f image_tag=main-abc12345
```

**Production:**
```bash
# Manual production deployment (still requires approval)
gh workflow run "CD - Production Deployment" \
  --ref main \
  -f image_tag=v1.2.3

# Admin-only: Skip approval (use with caution)
gh workflow run "CD - Production Deployment" \
  --ref main \
  -f image_tag=v1.2.3 \
  -f skip_approval=true
```

**Note:** Production deployments **always require approval** unless explicitly skipped by admins via manual trigger with `skip_approval=true`.

### Monitoring Pipeline

1. **GitHub Actions Tab:** View workflow runs and logs
2. **Security Tab:** Review security scan results
3. **Releases Tab:** View version tags and releases
4. **Environments Tab:** Monitor deployment approvals

### Rollback Procedure

#### Automatic Rollback
- Triggered automatically on deployment failure
- Uses Helm rollback to previous revision
- Notifications sent on rollback

#### Manual Rollback
```bash
# Connect to cluster
aws eks update-kubeconfig --name <cluster-name> --region eu-west-2

# Rollback deployment
helm rollback titanic-api-prod -n titanic-api-prod

# Or using kubectl
kubectl rollout undo deployment/titanic-api-prod -n titanic-api-prod
```

## Best Practices Implemented

### 1. Security
- ✅ Container image scanning (Trivy)
- ✅ Code security scanning (Bandit)
- ✅ Secrets management via GitHub Secrets
- ✅ IRSA for AWS authentication (no long-lived credentials)
- ✅ Non-root containers
- ✅ Read-only root filesystem

### 2. Efficiency
- ✅ Docker layer caching (BuildKit cache)
- ✅ Parallel job execution
- ✅ Conditional job execution
- ✅ Artifact caching

### 3. Reliability
- ✅ Atomic deployments (Helm `--atomic` flag)
- ✅ Automatic rollback on failure
- ✅ Health checks and readiness probes
- ✅ Deployment verification
- ✅ Smoke tests after deployment

### 4. Observability
- ✅ Coverage reporting (Codecov)
- ✅ Security scan results in GitHub Security tab
- ✅ Deployment status notifications
- ✅ Rollback notifications

### 5. Versioning
- ✅ Semantic versioning
- ✅ Git tags for releases
- ✅ GitHub Releases
- ✅ Image tagging strategy

## Security Features

### Authentication and Authorization

**IRSA (IAM Roles for Service Accounts):**
- No long-lived AWS credentials stored in GitHub
- Temporary credentials via OIDC
- Role-based access control per environment

**GitHub Environments:**
- Production environment requires manual approval
- Branch restrictions for production deployments
- Reviewer requirements configurable

### Secrets Management

- All sensitive data stored in GitHub Secrets
- Secrets never exposed in logs
- Automatic secret rotation support
- Environment-specific secrets

### Security Scanning

**Code Scanning:**
- Trivy filesystem scan for dependencies
- Bandit for Python security issues
- Results uploaded to GitHub Security tab

**Container Scanning:**
- Trivy image scan before push
- Critical and high severity checks
- SARIF format for GitHub integration

### Network Security

- ECR private repositories
- EKS private endpoint support
- Network policies in Kubernetes

## Troubleshooting

### Common Issues

#### 1. Pipeline Fails at Test Stage
- **Check:** Test coverage below threshold
- **Solution:** Increase test coverage or adjust threshold
- **Check:** Linter errors
- **Solution:** Fix code style issues

#### 2. Build Fails
- **Check:** Dockerfile syntax
- **Solution:** Validate Dockerfile locally
- **Check:** ECR authentication
- **Solution:** Verify AWS_ROLE_ARN_CI has correct permissions
- **Check:** ECR repository creation
- **Solution:** Verify role has ecr:CreateRepository permission

#### 3. Deployment Fails
- **Check:** Kubernetes cluster connectivity
- **Solution:** Verify AWS credentials and cluster name
- **Check:** Helm chart validation
- **Solution:** Run `helm lint` locally
- **Check:** Resource availability
- **Solution:** Check cluster capacity
- **Check:** Image pull errors
- **Solution:** Verify image exists in ECR and role has ECR read permissions

#### 4. Production Approval Not Working
- **Check:** Environment protection rules
- **Solution:** Verify environment configuration
- **Check:** User permissions
- **Solution:** Ensure user has deployment permissions

### Debug Commands

```bash
# View workflow logs
gh run view <run-id> --log

# Rerun failed workflow
gh run rerun <run-id>

# Cancel running workflow
gh run cancel <run-id>

# List recent runs
gh run list --workflow="CI Pipeline"
```

### IAM Troubleshooting

**Issue: "Access Denied" when pushing to ECR**
- Verify CI role has ECR permissions
- Check trust policy includes correct GitHub repository
- Verify OIDC provider is configured

**Issue: "Cannot assume role"**
- Verify role ARN is correct in GitHub secrets
- Check trust policy conditions match your repository
- Ensure OIDC provider exists

**Issue: "Cluster not found"**
- Verify cluster name secret matches actual EKS cluster name
- Check AWS region is correct
- Verify deployment role has EKS access permissions

**Issue: "Image not found in ECR"**
- Ensure CI pipeline completed successfully
- Check image tag matches what deployment expects
- Verify ECR repository name is correct

## Compliance with Requirements

### Requirement 1: Continuous Integration

**Status:** ✅ Complete

- ✅ Automated testing (pytest with coverage)
- ✅ Code quality checks (flake8, black, isort, mypy)
- ✅ Coverage thresholds (70% minimum)
- ✅ Security scanning (Trivy, Bandit)
- ✅ Build and push Docker image to ECR
- ✅ Multi-platform builds
- ✅ Build caching

### Requirement 2: Continuous Deployment

**Status:** ✅ Complete

- ✅ Automated deployment to Kubernetes
- ✅ Multi-environment strategy (dev/staging/production)
- ✅ Deployment approval gates for production
- ✅ Automated rollback on failure
- ✅ Health checks and smoke tests
- ✅ Deployment verification

### Requirement 3: Pipeline Best Practices

**Status:** ✅ Complete

- ✅ Semantic versioning for images
- ✅ Caching for faster builds
- ✅ Parallel job execution
- ✅ Secrets management
- ✅ Deployment notifications (ready for integration)

## Known Limitations

1. **Notification Integration:** Slack/Email notifications are configured but require webhook URLs to be set up
2. **Multi-Region:** Currently supports single AWS region (configurable via secrets)
3. **Database Migrations:** Database migrations are not automatically handled in the pipeline
4. **Feature Flags:** No integration with feature flag services
5. **Performance Testing:** Load testing is not included in the pipeline
6. **Cost Monitoring:** No automated cost tracking for deployments

## Future Enhancements

### Planned Improvements
1. **Blue-Green Deployments:** Zero-downtime deployments with traffic shifting
2. **Canary Releases:** Gradual traffic shifting for production
3. **Performance Testing:** Load testing in staging environment
4. **Database Migrations:** Automated migration handling
5. **Feature Flags:** Integration with feature flag service
6. **Cost Monitoring:** Track deployment costs
7. **Advanced Notifications:** Slack/Email with rich formatting
8. **Deployment Metrics:** Track deployment success rates

### Integration Opportunities
- **Monitoring:** Prometheus/Grafana integration
- **Logging:** Centralized log aggregation
- **APM:** Application Performance Monitoring
- **Chaos Engineering:** Failure injection testing

## References

### GitHub Actions
- GitHub Actions Documentation: https://docs.github.com/en/actions
- GitHub Actions Workflow Syntax: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
- GitHub Actions Best Practices: https://docs.github.com/en/actions/learn-github-actions/best-practices
- GitHub Environments: https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment
- GitHub OIDC with AWS: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

### AWS Services
- Amazon ECR Documentation: https://docs.aws.amazon.com/ecr/
- AWS EKS Documentation: https://docs.aws.amazon.com/eks/
- IAM Roles for Service Accounts (IRSA): https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- AWS IAM OIDC Identity Providers: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html

### CI/CD Best Practices
- Continuous Integration Best Practices: https://www.thoughtworks.com/continuous-integration
- Continuous Deployment Best Practices: https://www.thoughtworks.com/continuous-delivery
- The Twelve-Factor App: https://12factor.net/
- DevOps Best Practices: https://www.atlassian.com/devops

### Testing and Quality
- pytest Documentation: https://docs.pytest.org/
- Coverage.py Documentation: https://coverage.readthedocs.io/
- Flake8 Documentation: https://flake8.pycqa.org/
- Black Code Formatter: https://black.readthedocs.io/
- mypy Type Checking: https://mypy.readthedocs.io/

### Security Scanning
- Trivy Documentation: https://aquasecurity.github.io/trivy/
- Bandit Security Linter: https://bandit.readthedocs.io/
- OWASP Top 10: https://owasp.org/www-project-top-ten/
- Container Security Best Practices: https://kubernetes.io/docs/concepts/security/pod-security-standards/

### Docker and Containerization
- Docker Best Practices: https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- Multi-platform Builds: https://docs.docker.com/build/building/multi-platform/
- Docker Buildx: https://docs.docker.com/build/building/multi-platform/

### Helm
- Helm Documentation: https://helm.sh/docs/
- Helm Best Practices: https://helm.sh/docs/chart_best_practices/
- Helm Rollback: https://helm.sh/docs/helm/helm_rollback/

### Semantic Versioning
- Semantic Versioning Specification: https://semver.org/
- Conventional Commits: https://www.conventionalcommits.org/

### Monitoring and Observability
- GitHub Actions Monitoring: https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows
- Codecov Documentation: https://docs.codecov.com/
- GitHub Security Advisories: https://docs.github.com/en/code-security/security-advisories

## Conclusion

The CI/CD pipeline implementation for the Titanic API provides a production-ready, secure, and efficient continuous integration and deployment solution. All requirements from Part 3 of the technical assessment have been met, including comprehensive testing, security scanning, automated deployments, and production approval gates.

The pipeline follows industry best practices with proper security controls, efficient caching strategies, and reliable deployment mechanisms. The use of AWS ECR and IRSA ensures secure authentication without long-lived credentials, while the multi-environment strategy provides proper separation between development, staging, and production deployments.

The implementation is ready for production use and can be easily extended with additional features such as blue-green deployments, canary releases, and advanced monitoring integrations.

---

**Last Updated:** 2024-01-24  
**Pipeline Version:** 1.0.0  
**Maintainer:** DevOps Team
