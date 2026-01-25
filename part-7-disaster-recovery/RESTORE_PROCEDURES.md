# Restore Procedures

## Overview

This document provides detailed procedures for restoring the Titanic API infrastructure from backups, including database restoration, application restoration, and infrastructure restoration.

## Restore Scenarios

### Scenario 1: Restore Database from Snapshot

**Use Case:**
- Database corruption
- Accidental data deletion
- Need to restore to known good state

**Prerequisites:**
- Snapshot ID or timestamp
- Target database instance name
- Sufficient storage capacity

**Steps:**

1. **List Available Snapshots**
   ```bash
   # List automated backups
   aws rds describe-db-snapshots \
     --db-instance-identifier titanic-api-prod-db \
     --region eu-west-2 \
     --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
     --output table
   
   # List manual snapshots
   aws rds describe-db-snapshots \
     --snapshot-type manual \
     --region eu-west-2 \
     --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
     --output table
   ```

2. **Restore from Snapshot**
   ```bash
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier titanic-api-prod-db-restored \
     --db-snapshot-identifier <snapshot-id> \
     --db-instance-class db.t3.medium \
     --publicly-accessible false \
     --region eu-west-2
   ```

3. **Monitor Restoration**
   ```bash
   # Watch restoration progress
   watch -n 10 'aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db-restored \
     --region eu-west-2 \
     --query "DBInstances[0].DBInstanceStatus" \
     --output text'
   ```

4. **Verify Database**
   ```bash
   # Get endpoint
   ENDPOINT=$(aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db-restored \
     --region eu-west-2 \
     --query 'DBInstances[0].Endpoint.Address' \
     --output text)
   
   # Test connection
   psql -h $ENDPOINT -U <username> -d <database> -c "SELECT COUNT(*) FROM people"
   ```

5. **Update Application Configuration**
   ```bash
   # Update endpoint in Secrets Manager
   aws secretsmanager update-secret \
     --secret-id titanic-api-prod-rds-credentials \
     --secret-string "{\"postgres-rds-endpoint\": \"$ENDPOINT\"}" \
     --region eu-west-2
   ```

6. **Restart Application Pods**
   ```bash
   # Restart pods to pick up new endpoint
   kubectl rollout restart deployment/titanic-api-prod -n titanic-api-prod
   ```

**Expected Duration**: 15-30 minutes

### Scenario 2: Point-in-Time Recovery (PITR)

**Use Case:**
- Need to restore to specific point in time
- Data corruption at known time
- Accidental deletion at known time

**Prerequisites:**
- Source database instance
- Target point in time (within retention period)
- Target database instance name

**Steps:**

1. **Determine Restore Time**
   ```bash
   # Find last known good time
   # Check application logs, database logs, or monitoring data
   RESTORE_TIME="2025-01-25T10:00:00Z"
   ```

2. **Restore to Point in Time**
   ```bash
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier titanic-api-prod-db \
     --target-db-instance-identifier titanic-api-prod-db-restored \
     --restore-time $RESTORE_TIME \
     --db-instance-class db.t3.medium \
     --publicly-accessible false \
     --region eu-west-2
   ```

3. **Monitor Restoration**
   ```bash
   # Watch restoration progress
   watch -n 10 'aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db-restored \
     --region eu-west-2 \
     --query "DBInstances[0].DBInstanceStatus" \
     --output text'
   ```

4. **Verify Data at Restore Point**
   ```bash
   # Connect and verify data
   ENDPOINT=$(aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db-restored \
     --region eu-west-2 \
     --query 'DBInstances[0].Endpoint.Address' \
     --output text)
   
   psql -h $ENDPOINT -U <username> -d <database> -c \
     "SELECT COUNT(*), MAX(created_at) FROM people"
   ```

5. **Update Application and Verify**
   ```bash
   # Update endpoint
   aws secretsmanager update-secret \
     --secret-id titanic-api-prod-rds-credentials \
     --secret-string "{\"postgres-rds-endpoint\": \"$ENDPOINT\"}" \
     --region eu-west-2
   
   # Restart application
   kubectl rollout restart deployment/titanic-api-prod -n titanic-api-prod
   
   # Verify application
   curl https://titanic-api.iyere.site/health
   ```

**Expected Duration**: 30-60 minutes

### Scenario 3: Restore Application Deployment

**Use Case:**
- Application deployment failure
- Need to rollback to previous version
- Application bugs

**Steps:**

1. **Check Deployment History**
   ```bash
   helm history titanic-api-prod -n titanic-api-prod
   ```

2. **Rollback to Previous Version**
   ```bash
   # Rollback to previous revision
   helm rollback titanic-api-prod -n titanic-api-prod
   
   # Or rollback to specific revision
   helm rollback titanic-api-prod -n titanic-api-prod 2
   ```

3. **Monitor Rollback**
   ```bash
   kubectl rollout status deployment/titanic-api-prod -n titanic-api-prod
   ```

4. **Verify Application**
   ```bash
   # Check pods
   kubectl get pods -n titanic-api-prod
   
   # Check health
   curl https://titanic-api.iyere.site/health
   
   # Test functionality
   curl https://titanic-api.iyere.site/people
   ```

**Expected Duration**: 5-10 minutes

### Scenario 4: Restore Infrastructure from Terraform

**Use Case:**
- Infrastructure failure
- Need to recreate infrastructure
- Disaster recovery

**Steps:**

1. **Verify Terraform State**
   ```bash
   cd part-5-iac/terraform
   terraform workspace select prod
   terraform init -backend-config=environments/prod/backend.hcl
   terraform state list
   ```

2. **Review Current State**
   ```bash
   terraform plan -var-file=environments/prod/terraform.tfvars
   ```

3. **Restore Infrastructure**
   ```bash
   # Apply configuration
   terraform apply -var-file=environments/prod/terraform.tfvars
   
   # Or restore specific resources
   terraform apply -target=module.eks -var-file=environments/prod/terraform.tfvars
   ```

4. **Verify Infrastructure**
   ```bash
   # Check EKS cluster
   aws eks describe-cluster --name titanic-api-prod --region eu-west-2
   
   # Check RDS instance
   aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db \
     --region eu-west-2
   ```

5. **Redeploy Application**
   ```bash
   # Update kubeconfig
   aws eks update-kubeconfig --name titanic-api-prod --region eu-west-2
   
   # Deploy application
   helm upgrade --install titanic-api-prod \
     ./part-2-kubernetes/helm/titanic-api \
     --namespace titanic-api-prod \
     --create-namespace
   ```

**Expected Duration**: 30-60 minutes

### Scenario 5: Restore from Cross-Region Snapshot

**Use Case:**
- Regional disaster
- Need to restore in different region
- Cross-region recovery

**Steps:**

1. **Copy Snapshot to Target Region**
   ```bash
   aws rds copy-db-snapshot \
     --source-db-snapshot-identifier <source-snapshot-id> \
     --target-db-snapshot-identifier titanic-api-prod-dr-snapshot \
     --source-region eu-west-2 \
     --target-region us-east-1
   ```

2. **Monitor Snapshot Copy**
   ```bash
   watch -n 30 'aws rds describe-db-snapshots \
     --db-snapshot-identifier titanic-api-prod-dr-snapshot \
     --region us-east-1 \
     --query "DBSnapshots[0].Status" \
     --output text'
   ```

3. **Restore from Copied Snapshot**
   ```bash
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier titanic-api-prod-dr \
     --db-snapshot-identifier titanic-api-prod-dr-snapshot \
     --db-instance-class db.t3.medium \
     --region us-east-1
   ```

4. **Deploy Infrastructure in Target Region**
   ```bash
   cd part-5-iac/terraform
   terraform workspace select prod-dr
   terraform init -backend-config=environments/prod-dr/backend.hcl
   terraform apply -var-file=environments/prod-dr/terraform.tfvars
   ```

5. **Deploy Application**
   ```bash
   aws eks update-kubeconfig --name titanic-api-prod-dr --region us-east-1
   
   helm upgrade --install titanic-api-prod \
     ./part-2-kubernetes/helm/titanic-api \
     --namespace titanic-api-prod \
     --set image.repository=<ecr-repo-us-east-1>
   ```

**Expected Duration**: 1-2 hours

## Restore Verification

### Database Verification

```bash
# Check data integrity
psql -h <endpoint> -U <user> -d <database> << EOF
SELECT COUNT(*) FROM people;
SELECT MAX(uuid) FROM people;
SELECT MIN(created_at), MAX(created_at) FROM people;
EOF

# Check database size
psql -h <endpoint> -U <user> -d <database> -c \
  "SELECT pg_size_pretty(pg_database_size(current_database()));"
```

### Application Verification

```bash
# Health check
curl https://titanic-api.iyere.site/health

# Functional test
curl https://titanic-api.iyere.site/people

# Check logs
kubectl logs -n titanic-api-prod -l app=titanic-api --tail=100
```

### Infrastructure Verification

```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes

# Check resources
kubectl get all -n titanic-api-prod

# Check ingress
kubectl get ingress -n titanic-api-prod
```

## Restore Testing

### Regular Testing Schedule

**Monthly:**
- Test database restore from snapshot
- Test application rollback
- Verify restore procedures

**Quarterly:**
- Test point-in-time recovery
- Test cross-region restore
- Full restore drill

**Annually:**
- Complete disaster recovery exercise
- Test all restore scenarios
- Update procedures

### Testing Checklist

- [ ] Database snapshot restore
- [ ] Point-in-time recovery
- [ ] Application rollback
- [ ] Infrastructure restoration
- [ ] Cross-region restore
- [ ] Data integrity verification
- [ ] Application functionality verification

## Restore Best Practices

### Do's ✅
- Test restore procedures regularly
- Verify data integrity after restore
- Document restore steps
- Keep restore procedures updated
- Test in non-production first
- Monitor restore progress

### Don'ts ❌
- Don't restore to production without testing
- Don't skip verification steps
- Don't restore without backup verification
- Don't forget to update application configuration
- Don't skip post-restore monitoring

## References

- [AWS RDS Restore](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_RestoreFromSnapshot.html)
- [AWS RDS PITR](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)
