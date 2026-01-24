# Testing Your CI/CD Pipeline

## Pre-Flight Checklist

Before testing, ensure you have:

- [ ] All required GitHub secrets configured
- [ ] IAM user has correct permissions
- [ ] ECR repository exists (or will be auto-created)
- [ ] EKS cluster is accessible
- [ ] Code is pushed to the repository

---

## Step 1: Verify GitHub Secrets

### Check Secrets Are Set

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Verify these secrets exist:
   - ✅ `AWS_ACCESS_KEY_ID`
   - ✅ `AWS_SECRET_ACCESS_KEY`
   - ✅ `ECR_REPOSITORY_URL` (recommended)
   - ✅ `AWS_REGION` (recommended)
   - ✅ `EKS_CLUSTER_NAME_PROD`

### Test AWS Credentials Locally

```bash
# Set your credentials as environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="eu-west-2"

# Test ECR access
aws ecr get-authorization-token --region eu-west-2

# Test EKS access
aws eks list-clusters --region eu-west-2

# Test specific cluster access
aws eks describe-cluster --name <your-cluster-name> --region eu-west-2
```

---

## Step 2: Test CI Pipeline (Build & Push)

### Option A: Trigger via Push (Recommended)

1. **Make a small change** to trigger the CI pipeline:
   ```bash
   # Make a small change to trigger CI
   echo "# Test CI Pipeline" >> titanic-api/README.md
   git add titanic-api/README.md
   git commit -m "test: trigger CI pipeline"
   git push origin main  # or develop
   ```

2. **Monitor the workflow:**
   - Go to **Actions** tab in GitHub
   - Click on the running workflow
   - Watch each job:
     - ✅ `test` - Should pass
     - ✅ `security-scan` - Should complete
     - ✅ `build` - Should build and push image

### Option B: Trigger via Pull Request

1. Create a new branch:
   ```bash
   git checkout -b test/ci-pipeline
   ```

2. Make a small change and push:
   ```bash
   echo "# Test CI" >> titanic-api/README.md
   git add titanic-api/README.md
   git commit -m "test: CI pipeline"
   git push origin test/ci-pipeline
   ```

3. Create a Pull Request to `main` or `develop`

4. The CI pipeline will run automatically

### What to Check in CI Pipeline

**Test Job:**
- ✅ Tests run successfully
- ✅ Coverage meets threshold (70%)
- ✅ Linting passes

**Security Scan Job:**
- ✅ Trivy scan completes
- ✅ Bandit scan completes

**Build Job:**
- ✅ Docker image builds successfully
- ✅ Image is pushed to ECR
- ✅ Image scan completes

**Verify Image in ECR:**
```bash
# List images in your repository
aws ecr list-images \
  --repository-name titanic-api/titanic-api-repo \
  --region eu-west-2

# Describe a specific image
aws ecr describe-images \
  --repository-name titanic-api/titanic-api-repo \
  --image-ids imageTag=main-<sha> \
  --region eu-west-2
```

---

## Step 3: Test Production Deployment Pipeline

### Option A: Manual Workflow Dispatch (Recommended for Testing)

1. **Go to Actions tab** in GitHub
2. **Select "CD - Production Deployment"** workflow
3. **Click "Run workflow"**
4. **Enter required inputs:**
   - `image_tag`: Use a tag that exists in ECR (e.g., `main-abc12345` or `latest`)
   - `skip_approval`: Leave unchecked (unless you want to skip approval)
5. **Click "Run workflow"**

### Option B: Trigger via Staging Completion

1. First ensure staging deployment completes successfully
2. Production deployment will trigger automatically (still requires approval)

### What to Check in CD Pipeline

**Pre-Deployment Checks:**
- ✅ Image verification succeeds
- ✅ Image exists in ECR

**Deployment Job:**
- ✅ AWS credentials configured
- ✅ kubectl configured
- ✅ EKS cluster connection successful
- ✅ Helm deployment succeeds
- ✅ Pods become ready
- ✅ Smoke tests pass

**Verify Deployment:**
```bash
# Set your AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="eu-west-2"

# Configure kubectl
aws eks update-kubeconfig --name <your-cluster-name> --region eu-west-2

# Check deployment status
kubectl get pods -n titanic-api-prod
kubectl get deployment titanic-api-prod -n titanic-api-prod
kubectl get ingress titanic-api-prod -n titanic-api-prod

# Check deployment logs
kubectl logs -n titanic-api-prod -l app=titanic-api --tail=50
```

---

## Step 4: Common Issues and Solutions

### Issue: "Access Denied" in CI Pipeline

**Symptoms:**
- Build job fails with AWS access denied errors

**Solutions:**
1. Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are correct
2. Check IAM user has ECR permissions (especially `ecr:ListImages`)
3. Verify `ECR_REPOSITORY_URL` is correct

**Test:**
```bash
aws ecr get-authorization-token --region eu-west-2
aws ecr list-images --repository-name titanic-api/titanic-api-repo --region eu-west-2
```

### Issue: "Cannot connect to EKS cluster" in CD Pipeline

**Symptoms:**
- Deployment fails with "cluster not found" or "access denied"

**Solutions:**
1. Verify `EKS_CLUSTER_NAME_PROD` matches actual cluster name exactly
2. Check IAM user has `eks:DescribeCluster` permission
3. Verify cluster is in the correct region (`eu-west-2`)
4. Check cluster's IAM configuration allows your IAM user

**Test:**
```bash
# List clusters
aws eks list-clusters --region eu-west-2

# Describe your cluster
aws eks describe-cluster --name <your-cluster-name> --region eu-west-2

# Try to update kubeconfig
aws eks update-kubeconfig --name <your-cluster-name> --region eu-west-2
```

### Issue: "Image not found in ECR"

**Symptoms:**
- Pre-deployment check fails with "Image not found"

**Solutions:**
1. Ensure CI pipeline completed successfully
2. Verify image tag matches what you're trying to deploy
3. Check image exists in ECR:
   ```bash
   aws ecr describe-images \
     --repository-name titanic-api/titanic-api-repo \
     --image-ids imageTag=<your-tag> \
     --region eu-west-2
   ```

### Issue: "Helm deployment fails"

**Symptoms:**
- Helm upgrade fails or times out

**Solutions:**
1. Check if namespace exists or can be created
2. Verify Helm chart is valid:
   ```bash
   helm lint ./part-2-kubernetes/helm/titanic-api
   ```
3. Check for resource constraints (CPU/memory)
4. Verify image pull secrets if using private registry
5. Check pod events:
   ```bash
   kubectl get events -n titanic-api-prod --sort-by='.lastTimestamp'
   ```

---

## Step 5: End-to-End Test

### Complete Test Flow

1. **Make a code change:**
   ```bash
   # Make a small change
   echo "# Test E2E" >> titanic-api/README.md
   git add titanic-api/README.md
   git commit -m "test: end-to-end pipeline test"
   git push origin main
   ```

2. **Wait for CI to complete:**
   - Monitor in Actions tab
   - Note the image tag created (e.g., `main-abc12345`)

3. **Deploy to production:**
   - Go to Actions → "CD - Production Deployment"
   - Click "Run workflow"
   - Enter the image tag from step 2
   - Approve if required
   - Monitor deployment

4. **Verify deployment:**
   ```bash
   # Check pods are running
   kubectl get pods -n titanic-api-prod
   
   # Check service is accessible
   kubectl get ingress -n titanic-api-prod
   
   # Test the application
   curl https://titanic-api.iyere.site/health
   ```

---

## Quick Test Commands

### Test AWS Access
```bash
# Test ECR
aws ecr describe-repositories --region eu-west-2
aws ecr list-images --repository-name titanic-api/titanic-api-repo --region eu-west-2

# Test EKS
aws eks list-clusters --region eu-west-2
aws eks describe-cluster --name <your-cluster-name> --region eu-west-2
```

### Test Kubernetes Access
```bash
# Configure kubectl
aws eks update-kubeconfig --name <your-cluster-name> --region eu-west-2

# Test access
kubectl get nodes
kubectl get namespaces
```

### Test Helm Chart
```bash
# Lint the chart
helm lint ./part-2-kubernetes/helm/titanic-api

# Dry-run deployment
helm upgrade --install titanic-api-prod \
  ./part-2-kubernetes/helm/titanic-api \
  --namespace titanic-api-prod \
  --dry-run \
  --debug
```

---

## Monitoring Pipeline Execution

### GitHub Actions Logs

1. **Go to Actions tab**
2. **Click on the workflow run**
3. **Click on each job** to see detailed logs
4. **Look for:**
   - ✅ Green checkmarks = Success
   - ❌ Red X = Failure
   - ⚠️ Yellow circle = In progress or warning

### Key Log Sections to Check

**CI Pipeline:**
- Test results and coverage
- Security scan results
- Docker build output
- ECR push confirmation

**CD Pipeline:**
- AWS credential configuration
- EKS cluster connection
- Helm deployment output
- Pod status
- Health check results

---

## Success Criteria

### CI Pipeline Success:
- ✅ All tests pass
- ✅ Coverage ≥ 70%
- ✅ Security scans complete
- ✅ Docker image built and pushed to ECR
- ✅ Image tag created (visible in ECR)

### CD Pipeline Success:
- ✅ Image verified in ECR
- ✅ EKS cluster connection successful
- ✅ Helm deployment completes
- ✅ All pods in "Running" state
- ✅ Health checks pass
- ✅ Application accessible via ingress

---

## Next Steps After Successful Test

1. **Monitor the deployment** for a few minutes
2. **Check application logs** for any errors
3. **Test the API endpoints** manually
4. **Verify TLS certificate** is issued (if using cert-manager)
5. **Check metrics** (if Prometheus is configured)

If everything works, your pipeline is ready for production use! 🎉
