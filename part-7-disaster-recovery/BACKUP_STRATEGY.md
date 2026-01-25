# Backup Strategy

## Executive Summary

This document outlines the comprehensive backup strategy for the Titanic API infrastructure, covering database backups, configuration backups, infrastructure state backups, and application image backups.

## Backup Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Backup Layers                             │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: Database Backups                                  │
│   - RDS automated daily backups                             │
│   - Point-in-time recovery (PITR)                           │
│   - Cross-region snapshot replication (production)          │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Configuration Backups                             │
│   - Terraform state in S3 (versioned)                        │
│   - Git repository (all infrastructure code)                 │
│   - AWS Secrets Manager (encrypted secrets)                  │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: Application Backups                               │
│   - Container images in ECR                                 │
│   - Kubernetes manifests in Git                             │
│   - Helm charts in Git                                      │
└─────────────────────────────────────────────────────────────┘
```

## 1. Database Backup Strategy

### 1.1 RDS Automated Backups

**Configuration:**
- **Enabled**: Yes (automatically enabled for RDS instances)
- **Backup Window**: Configured per environment (low-traffic hours)
- **Retention Period**:
  - Development: 7 days
  - Staging: 14 days
  - Production: 30 days

**Backup Features:**
- Automated daily backups
- Transaction log backups (for PITR)
- Multi-AZ backup storage
- Encrypted backups (using KMS)

**Backup Schedule:**
- **Development**: Daily at 02:00 UTC
- **Staging**: Daily at 01:00 UTC
- **Production**: Daily at 00:00 UTC

### 1.2 Point-in-Time Recovery (PITR)

**Configuration:**
- **Enabled**: Yes
- **Retention**: Same as automated backups
- **Granularity**: 5-minute intervals

**Capabilities:**
- Restore to any point in time within retention period
- No data loss (up to 5 minutes)
- Automatic transaction log backups

**Use Cases:**
- Accidental data deletion
- Data corruption
- Application errors causing data issues

### 1.3 Manual Snapshots

**When to Create:**
- Before major application deployments
- Before database schema changes
- Before infrastructure changes
- On-demand for specific requirements

**Retention:**
- Manual snapshots retained until explicitly deleted
- Recommended: Keep for 90 days, then archive or delete

**Creation:**
```bash
# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier titanic-api-prod-db \
  --db-snapshot-identifier titanic-api-prod-manual-$(date +%Y%m%d-%H%M%S) \
  --region eu-west-2
```

### 1.4 Cross-Region Backup Replication

**Production Only:**
- Automated backups replicated to secondary region (us-east-1)
- Manual snapshots can be copied to secondary region
- Enables fast recovery in case of regional failure

**Replication Configuration:**
```bash
# Copy snapshot to secondary region
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier titanic-api-prod-snapshot \
  --target-db-snapshot-identifier titanic-api-prod-dr-snapshot \
  --source-region eu-west-2 \
  --target-region us-east-1
```

## 2. Configuration Backup Strategy

### 2.1 Terraform State Backups

**Storage:**
- S3 bucket with versioning enabled
- DynamoDB table for state locking
- Separate buckets per environment

**Backup Features:**
- Versioning enabled (all state changes retained)
- Encryption at rest (SSE-S3 or KMS)
- Lifecycle policies for old versions
- Cross-region replication (production)

**Retention:**
- Development: 30 days
- Staging: 90 days
- Production: 1 year

**State Backup Locations:**
- Development: `titanic-api-terraform-state-dev`
- Staging: `titanic-api-terraform-state-staging`
- Production: `titanic-api-terraform-state-prod`

### 2.2 Git Repository Backups

**Content:**
- All infrastructure code (Terraform, Kubernetes manifests)
- CI/CD pipeline configurations
- Documentation
- Application source code

**Backup Methods:**
- Primary: GitHub repository (with Git LFS for large files)
- Secondary: Regular clones to secure storage
- Automated: GitHub Actions can trigger backups

**Retention:**
- Indefinite (Git history preserved)
- Tagged releases retained permanently

### 2.3 Secrets Backup

**Storage:**
- AWS Secrets Manager (primary)
- Encrypted at rest
- Versioned (keeps previous versions)

**Backup Strategy:**
- Secrets Manager automatically versions secrets
- Previous versions retained for 30 days (configurable)
- Cross-region replication for production secrets

**Manual Backup:**
```bash
# Export secrets (for documentation/audit)
aws secretsmanager get-secret-value \
  --secret-id titanic-api-prod-rds-credentials \
  --region eu-west-2 \
  --query SecretString \
  --output text > secrets-backup-$(date +%Y%m%d).json
```

**Note**: Store exported secrets securely (encrypted) and delete after verification.

## 3. Application Backup Strategy

### 3.1 Container Image Backups

**Storage:**
- ECR repositories (primary)
- Image scanning enabled
- Lifecycle policies configured

**Retention:**
- Development: 30 days
- Staging: 90 days
- Production: 1 year (or until replaced)

**Lifecycle Policies:**
- Keep last 10 images per tag
- Keep images tagged with `latest`, `main`, `prod`
- Delete untagged images after 7 days

### 3.2 Kubernetes Configuration Backups

**Content:**
- All Kubernetes manifests
- Helm chart values
- Custom resources (CRDs)

**Backup Methods:**
- Git repository (primary)
- Periodic exports using `kubectl` or `velero` (optional)

**Export Script:**
```bash
# Export all resources from namespace
kubectl get all -n titanic-api-prod -o yaml > k8s-backup-$(date +%Y%m%d).yaml
```

## 4. Backup Verification

### 4.1 Automated Verification

**Database Backups:**
- Verify backup completion via CloudWatch alarms
- Test restore to non-production environment monthly
- Verify backup encryption

**Terraform State:**
- Verify state file integrity
- Test state restoration
- Verify versioning is working

### 4.2 Manual Verification

**Monthly Tasks:**
1. Verify recent backups exist
2. Test restore from backup (non-production)
3. Verify backup encryption
4. Check backup retention policies
5. Review backup logs for errors

**Quarterly Tasks:**
1. Full disaster recovery drill
2. Test cross-region restore
3. Verify backup automation scripts
4. Review and update backup procedures

## 5. Backup Automation

### 5.1 Automated Database Backups

**RDS Automated Backups:**
- Configured via Terraform
- Managed by AWS RDS
- No manual intervention required

**Configuration:**
```hcl
# In RDS module
backup_retention_period = 30  # days
backup_window           = "00:00-01:00"
copy_tags_to_snapshot   = true
enabled_cloudwatch_logs_exports = ["postgresql"]
```

### 5.2 Manual Snapshot Automation

**Pre-Deployment Snapshots:**
- Create snapshot before major deployments
- Automated via CI/CD pipeline (optional)
- Tagged with deployment version

**Script:** `scripts/backup-database.sh`

### 5.3 Configuration Backup Automation

**Terraform State:**
- Automatically backed up via S3 versioning
- No additional automation needed

**Git Repository:**
- Automatically backed up via Git
- GitHub provides redundancy

## 6. Backup Monitoring

### 6.1 CloudWatch Alarms

**Database Backup Alarms:**
- Backup failure alerts
- Backup completion notifications
- Backup size monitoring

**State Backup Alarms:**
- S3 bucket versioning status
- State file modification alerts

### 6.2 Backup Reports

**Weekly Reports:**
- Backup success/failure summary
- Backup size trends
- Retention policy compliance

**Monthly Reports:**
- Full backup audit
- Restore test results
- Backup cost analysis

## 7. Backup Retention Policy

### Summary Table

| Backup Type | Development | Staging | Production |
|-------------|-------------|---------|------------|
| RDS Automated | 7 days | 14 days | 30 days |
| RDS Manual Snapshots | 30 days | 90 days | 1 year |
| Terraform State | 30 days | 90 days | 1 year |
| Container Images | 30 days | 90 days | 1 year |
| Secrets Versions | 7 days | 14 days | 30 days |

## 8. Backup Costs

### Estimated Monthly Costs

**Development:**
- RDS backups: ~$5/month
- S3 storage: ~$2/month
- **Total: ~$7/month**

**Staging:**
- RDS backups: ~$10/month
- S3 storage: ~$5/month
- **Total: ~$15/month**

**Production:**
- RDS backups: ~$30/month
- S3 storage: ~$10/month
- Cross-region replication: ~$20/month
- **Total: ~$60/month**

## 9. Backup Best Practices

### Do's ✅
- Test backups regularly
- Verify backup encryption
- Keep backups in multiple regions (production)
- Document backup procedures
- Monitor backup completion
- Test restore procedures

### Don'ts ❌
- Don't store backups in same region only
- Don't skip backup verification
- Don't delete backups without verification
- Don't store unencrypted backups
- Don't rely on single backup method

## 10. References

- [AWS RDS Backup Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithAutomatedBackups.html)
- [AWS S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
