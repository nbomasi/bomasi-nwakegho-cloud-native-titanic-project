# GitHub Actions Secrets Configuration Guide

## Required GitHub Secrets

### CI Pipeline Secrets (Required for Building and Pushing Images)

| Secret Name | Required | Description | Example Value |
|------------|----------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | ✅ **Required** | AWS access key ID for CI pipeline (needs ECR push/pull permissions) | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | ✅ **Required** | AWS secret access key for CI pipeline | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `ECR_REPOSITORY_URL` | ⚠️ Optional* | Full ECR repository URL (recommended to set) | `456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo` |
| `AWS_REGION` | ⚠️ Optional* | AWS region | `eu-west-2` |

**Note:** *Optional secrets have defaults but are recommended to be set explicitly for clarity.

### CD Pipeline Secrets (Required for Deployments)

#### Development Environment

| Secret Name | Required | Description | Example Value |
|------------|----------|-------------|---------------|
| `AWS_ROLE_ARN_DEV` | ✅ **Required** | IAM role ARN for development deployments (OIDC) | `arn:aws:iam::456128143446:role/GitHubActions-Deploy-Dev` |
| `EKS_CLUSTER_NAME_DEV` | ✅ **Required** | Development EKS cluster name | `titanic-api-eks-dev` |

#### Staging Environment

| Secret Name | Required | Description | Example Value |
|------------|----------|-------------|---------------|
| `AWS_ROLE_ARN_STAGING` | ✅ **Required** | IAM role ARN for staging deployments (OIDC) | `arn:aws:iam::456128143446:role/GitHubActions-Deploy-Staging` |
| `EKS_CLUSTER_NAME_STAGING` | ✅ **Required** | Staging EKS cluster name | `titanic-api-eks-staging` |

#### Production Environment

| Secret Name | Required | Description | Example Value |
|------------|----------|-------------|---------------|
| `AWS_ROLE_ARN_PROD` | ✅ **Required** | IAM role ARN for production deployments (OIDC) | `arn:aws:iam::456128143446:role/GitHubActions-Deploy-Prod` |
| `EKS_CLUSTER_NAME_PROD` | ✅ **Required** | Production EKS cluster name | `titanic-api-eks-prod` |

### Optional Secrets

| Secret Name | Required | Description | Example Value |
|------------|----------|-------------|---------------|
| `SLACK_WEBHOOK_URL` | ❌ Optional | Slack webhook for deployment notifications | `https://hooks.slack.com/services/...` |

---

## Quick Setup Checklist

### Minimum Required Secrets (CI Only)
- [ ] `AWS_ACCESS_KEY_ID`
- [ ] `AWS_SECRET_ACCESS_KEY`
- [ ] `ECR_REPOSITORY_URL` (recommended)
- [ ] `AWS_REGION` (recommended)

### Full Setup (CI + CD)
- [ ] `AWS_ACCESS_KEY_ID`
- [ ] `AWS_SECRET_ACCESS_KEY`
- [ ] `ECR_REPOSITORY_URL`
- [ ] `AWS_REGION`
- [ ] `AWS_ROLE_ARN_DEV`
- [ ] `EKS_CLUSTER_NAME_DEV`
- [ ] `AWS_ROLE_ARN_STAGING`
- [ ] `EKS_CLUSTER_NAME_STAGING`
- [ ] `AWS_ROLE_ARN_PROD`
- [ ] `EKS_CLUSTER_NAME_PROD`

---

## How to Add Secrets in GitHub

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Enter the secret name (exactly as listed above, case-sensitive)
5. Enter the secret value
6. Click **Add secret**
7. Repeat for all required secrets

---

## Secret Details

### `AWS_ACCESS_KEY_ID` & `AWS_SECRET_ACCESS_KEY`
- **Purpose:** Used by CI pipeline to authenticate with AWS and push/pull Docker images to ECR
- **IAM Permissions Required:**
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

### `ECR_REPOSITORY_URL`
- **Purpose:** Full ECR repository URL for Docker image registry
- **Format:** `<account-id>.dkr.ecr.<region>.amazonaws.com/<repository-path>`
- **Example:** `456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo`
- **Default:** If not set, defaults to `456128143446.dkr.ecr.eu-west-2.amazonaws.com/titanic-api/titanic-api-repo`

### `AWS_REGION`
- **Purpose:** AWS region where resources are located
- **Default:** `eu-west-2` (if not set)
- **Example:** `eu-west-2`

### `AWS_ROLE_ARN_*` (Dev/Staging/Prod)
- **Purpose:** IAM role ARNs for OIDC authentication to deploy to EKS clusters
- **Format:** `arn:aws:iam::<account-id>:role/<role-name>`
- **Permissions Required:**
  - EKS cluster access (`eks:DescribeCluster`, `eks:ListClusters`)
  - ECR read access (`ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`)
  - Kubernetes API access (via EKS cluster)

### `EKS_CLUSTER_NAME_*` (Dev/Staging/Prod)
- **Purpose:** EKS cluster names for each environment
- **Format:** Cluster name as it appears in AWS EKS console
- **Example:** `titanic-api-eks-prod`

---

## Security Best Practices

1. **Never commit secrets to version control**
2. **Rotate credentials regularly** (especially `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`)
3. **Use least privilege** - Only grant necessary permissions to IAM users/roles
4. **Use OIDC roles for CD pipelines** - More secure than access keys
5. **Enable MFA** on AWS accounts
6. **Monitor secret usage** via AWS CloudTrail and GitHub Actions logs

---

## Troubleshooting

### CI Pipeline Fails with "Access Denied"
- Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are correct
- Check IAM user has required ECR permissions (especially `ecr:ListImages`)
- Verify `ECR_REPOSITORY_URL` is correct

### CD Pipeline Fails with "Cannot assume role"
- Verify `AWS_ROLE_ARN_*` values are correct
- Check OIDC provider is configured in AWS
- Verify trust policy allows GitHub Actions to assume the role

### Deployment Fails with "Cluster not found"
- Verify `EKS_CLUSTER_NAME_*` matches actual cluster name
- Check `AWS_REGION` is correct
- Verify IAM role has `eks:DescribeCluster` permission
