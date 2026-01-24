# GitHub Actions Secrets - Production Only Setup

## Required GitHub Secrets for CI + Production Deployment

### CI Pipeline Secrets (Required for Building and Pushing Images)

| Secret Name | Required | Description | Example Value |
|------------|----------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | ✅ **Required** | AWS access key ID for CI pipeline (needs ECR push/pull permissions) | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | ✅ **Required** | AWS secret access key for CI pipeline | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `ECR_REPOSITORY_URL` | ⚠️ Recommended | Full ECR repository URL | `456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo` |
| `AWS_REGION` | ⚠️ Recommended | AWS region | `eu-west-2` |

### Production Deployment Secrets

| Secret Name | Required | Description | Example Value |
|------------|----------|-------------|---------------|
| `EKS_CLUSTER_NAME_PROD` | ✅ **Required** | Production EKS cluster name | `titanic-api-eks-prod` |

**Note:** The production deployment uses the same `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as the CI pipeline. The IAM user needs both ECR permissions (for CI) and EKS permissions (for deployments).

---

## Quick Setup Checklist

### Minimum Required Secrets (5 total)
- [ ] `AWS_ACCESS_KEY_ID`
- [ ] `AWS_SECRET_ACCESS_KEY`
- [ ] `ECR_REPOSITORY_URL` (recommended)
- [ ] `AWS_REGION` (recommended)
- [ ] `EKS_CLUSTER_NAME_PROD`

---

## How to Add Secrets in GitHub

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Enter the secret name (exactly as listed above, case-sensitive)
5. Enter the secret value
6. Click **Add secret**
7. Repeat for all 5 secrets listed above

---

## Secret Details

### `AWS_ACCESS_KEY_ID` & `AWS_SECRET_ACCESS_KEY`
- **Purpose:** Used by both CI pipeline (to push images) and CD pipeline (to deploy to EKS)
- **IAM Permissions Required:**
  
  **For ECR (CI):**
  - `ecr:GetAuthorizationToken`
  - `ecr:BatchCheckLayerAvailability`
  - `ecr:GetDownloadUrlForLayer`
  - `ecr:BatchGetImage`
  - `ecr:PutImage`
  - `ecr:InitiateLayerUpload`
  - `ecr:UploadLayerPart`
  - `ecr:CompleteLayerUpload`
  - `ecr:DescribeRepositories`
  - `ecr:ListImages` ⚠️ **Required for list operations**
  - `ecr:DescribeImages`
  - `ecr:CreateRepository` (optional)
  
  **For EKS (CD):**
  - `eks:DescribeCluster`
  - `eks:ListClusters`
  - Kubernetes API access (via EKS cluster)

### `ECR_REPOSITORY_URL`
- **Purpose:** Full ECR repository URL for Docker image registry
- **Format:** `<account-id>.dkr.ecr.<region>.amazonaws.com/<repository-path>`
- **Example:** `456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo`
- **Default:** If not set, defaults to `456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo`

### `AWS_REGION`
- **Purpose:** AWS region where resources are located
- **Default:** `eu-west-2` (if not set)
- **Example:** `eu-west-2`

### `EKS_CLUSTER_NAME_PROD`
- **Purpose:** Production EKS cluster name
- **Format:** Cluster name as it appears in AWS EKS console
- **Example:** `titanic-api-eks-prod`
- **How to find:** Go to AWS EKS Console → Clusters → Copy the exact cluster name

---

## Summary

**Total Secrets Needed:** 5
- **2 Required for CI:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- **2 Recommended for CI:** `ECR_REPOSITORY_URL`, `AWS_REGION`
- **1 Required for Production:** `EKS_CLUSTER_NAME_PROD`

**Important:** Your IAM user needs permissions for both ECR (to push images) and EKS (to deploy). Make sure the IAM user has both sets of permissions.

Once these secrets are configured, your CI pipeline will build and push images, and your production deployment pipeline will deploy to your EKS cluster.
