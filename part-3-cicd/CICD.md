# CI/CD Design

The repository separates continuous integration, image publication, and environment deployment so each stage has a clear trust boundary.

## Continuous Integration

`.github/workflows/ci.yml` runs for pull requests and pushes to `main` or `develop`.

The required jobs are:

1. **Application:** install Python dependencies, run blocking-error lint checks, and execute tests against PostgreSQL.
2. **Terraform:** check canonical formatting, initialize without remote state, and validate the full configuration.
3. **Security:** scan the repository with Trivy and upload SARIF results to GitHub code scanning.

Application tests and Terraform validation are blocking. Security findings remain visible in GitHub for review and policy enforcement.

## Image Publication

Image publication runs only when the repository variable `ENABLE_IMAGE_PUSH` is `true`. This prevents a fork or demonstration repository from attempting to access AWS unexpectedly.

The build job:

- Waits for application, Terraform, and security jobs.
- Uses GitHub OIDC to assume a least-privilege AWS role.
- Builds the multi-stage application container.
- Pushes to the ECR URL configured in `ECR_REPOSITORY_URL`.
- Tags the image with the full Git commit SHA.

Mutable `latest` tags are not used for deployment.

## Deployment

`.github/workflows/cd.yml` is manually triggered and requires:

- A target GitHub environment: `development`, `staging`, or `production`.
- An immutable image tag that already exists in ECR.

The workflow verifies the image, configures access to the environment's EKS cluster, resolves replica settings, and deploys the Helm chart with `--atomic`. If installation or readiness checks fail, Helm restores the previous release.

Use GitHub environment protection rules to require review for staging and production.

## Required GitHub Configuration

| Name | Type | Scope | Purpose |
|---|---|---|---|
| `AWS_ROLE_ARN` | Secret | Repository or environment | AWS role trusted through GitHub OIDC |
| `AWS_REGION` | Variable | Repository | AWS region |
| `ECR_REPOSITORY_URL` | Variable | Repository | ECR repository URL |
| `EKS_CLUSTER_NAME` | Variable | Environment | Cluster selected for each environment |
| `ENABLE_IMAGE_PUSH` | Variable | Repository | Explicit image-publication switch |

## OIDC Trust

Create the GitHub OIDC provider in IAM and restrict the deployment role's trust policy to the intended repository, branch, or GitHub environment. The role should have only the ECR and EKS permissions required by its job.

Do not create IAM users or store long-lived AWS access keys in GitHub. Short-lived role sessions provide better traceability and remove credential-rotation overhead.

## Promotion Model

1. Merge a reviewed change after CI passes.
2. Publish the commit-SHA image.
3. Deploy that SHA to development.
4. Promote the same SHA to staging after verification.
5. Promote the same SHA to production after approval.

Reusing the same digest across environments prevents unreviewed rebuild differences.

## Rollback

Helm atomic deployment handles immediate rollout failure. For a later operational regression, redeploy a previously verified image SHA through the same workflow. This preserves an auditable deployment history instead of applying an untracked manual patch.
