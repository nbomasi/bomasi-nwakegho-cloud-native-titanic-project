# Disaster Recovery Procedures

## Executive Summary

This document provides comprehensive disaster recovery procedures for the Titanic API infrastructure, including RTO/RPO definitions, failover procedures, and recovery steps for various disaster scenarios.

## Recovery Objectives

### Recovery Time Objective (RTO)

**Definition**: Maximum acceptable time to restore service after a disaster.

| Environment | RTO | Rationale |
|-------------|-----|-----------|
| Development | 4 hours | Non-critical, can tolerate longer downtime |
| Staging | 2 hours | Important for testing, but not production-critical |
| Production | 1 hour | Critical for business operations |

### Recovery Point Objective (RPO)

**Definition**: Maximum acceptable data loss (time between last backup and disaster).

| Environment | RPO | Rationale |
|-------------|-----|-----------|
| Development | 24 hours | Can tolerate significant data loss |
| Staging | 12 hours | Moderate data loss acceptable |
| Production | 1 hour | Minimal data loss required (RDS PITR provides 5-minute granularity) |

## Disaster Scenarios

### Scenario 1: Database Failure

**Symptoms:**
- Database unavailable
- Application cannot connect to database
- Health checks failing

**Recovery Steps:**

1. **Assess Situation**
   ```bash
   # Check RDS instance status
   aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db \
     --region eu-west-2
   ```

2. **Determine Recovery Method**
   - **If Multi-AZ**: Automatic failover should occur (RTO: ~2 minutes)
   - **If Single-AZ**: Restore from backup (RTO: 15-30 minutes)

3. **Restore from Backup (if needed)**
   ```bash
   # Restore from latest automated backup
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier titanic-api-prod-db-restored \
     --db-snapshot-identifier <latest-snapshot-id> \
     --region eu-west-2
   ```

4. **Point-in-Time Recovery (if needed)**
   ```bash
   # Restore to specific point in time
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier titanic-api-prod-db \
     --target-db-instance-identifier titanic-api-prod-db-restored \
     --restore-time 2025-01-25T10:00:00Z \
     --region eu-west-2
   ```

5. **Update Application Configuration**
   ```bash
   # Update database endpoint in Secrets Manager
   aws secretsmanager update-secret \
     --secret-id titanic-api-prod-rds-credentials \
     --secret-string '{"postgres-rds-endpoint": "new-endpoint.rds.amazonaws.com"}' \
     --region eu-west-2
   ```

6. **Verify Application**
   ```bash
   # Check application health
   curl https://titanic-api.iyere.site/health
   ```

**Expected RTO**: 15-30 minutes (Single-AZ) or 2 minutes (Multi-AZ)

### Scenario 2: Application Failure

**Symptoms:**
- All pods crashing
- Application unavailable
- Health checks failing

**Recovery Steps:**

1. **Check Pod Status**
   ```bash
   kubectl get pods -n titanic-api-prod
   kubectl describe pods -n titanic-api-prod
   kubectl logs -n titanic-api-prod -l app=titanic-api --tail=100
   ```

2. **Rollback Deployment**
   ```bash
   # Rollback to previous Helm revision
   helm rollback titanic-api-prod -n titanic-api-prod
   
   # Or rollback to specific revision
   helm rollback titanic-api-prod -n titanic-api-prod 2
   ```

3. **Scale Up (if needed)**
   ```bash
   kubectl scale deployment titanic-api-prod -n titanic-api-prod --replicas=3
   ```

4. **Verify Recovery**
   ```bash
   kubectl rollout status deployment/titanic-api-prod -n titanic-api-prod
   curl https://titanic-api.iyere.site/health
   ```

**Expected RTO**: 5-10 minutes

### Scenario 3: Infrastructure Failure (EKS Cluster)

**Symptoms:**
- Cluster unavailable
- Cannot connect to cluster
- All workloads down

**Recovery Steps:**

1. **Assess Cluster Status**
   ```bash
   aws eks describe-cluster \
     --name titanic-api-prod \
     --region eu-west-2
   ```

2. **Check Node Status**
   ```bash
   kubectl get nodes
   kubectl get events --all-namespaces
   ```

3. **Restore from Terraform**
   ```bash
   cd part-5-iac/terraform
   terraform workspace select prod
   terraform init -backend-config=environments/prod/backend.hcl
   terraform plan -var-file=environments/prod/terraform.tfvars
   terraform apply -var-file=environments/prod/terraform.tfvars
   ```

4. **Redeploy Application**
   ```bash
   # Redeploy via CI/CD or manually
   helm upgrade --install titanic-api-prod \
     ./part-2-kubernetes/helm/titanic-api \
     --namespace titanic-api-prod \
     --create-namespace
   ```

**Expected RTO**: 30-60 minutes

### Scenario 4: Regional Failure

**Symptoms:**
- Entire AWS region unavailable
- All services down
- No connectivity

**Recovery Steps:**

1. **Failover to Secondary Region**
   ```bash
   # Update Route53 to point to secondary region
   aws route53 change-resource-record-sets \
     --hosted-zone-id <zone-id> \
     --change-batch file://failover-to-secondary.json
   ```

2. **Promote Read Replica (if exists)**
   ```bash
   aws rds promote-read-replica \
     --db-instance-identifier titanic-api-prod-dr \
     --region us-east-1
   ```

3. **Deploy Infrastructure in Secondary Region**
   ```bash
   cd part-5-iac/terraform
   terraform workspace select prod-dr
   terraform init -backend-config=environments/prod-dr/backend.hcl
   terraform apply -var-file=environments/prod-dr/terraform.tfvars
   ```

4. **Deploy Application**
   ```bash
   # Update kubeconfig for secondary region
   aws eks update-kubeconfig --name titanic-api-prod-dr --region us-east-1
   
   # Deploy application
   helm upgrade --install titanic-api-prod \
     ./part-2-kubernetes/helm/titanic-api \
     --namespace titanic-api-prod \
     --set image.repository=<ecr-repo-us-east-1>
   ```

**Expected RTO**: 1-2 hours

### Scenario 5: Data Corruption

**Symptoms:**
- Data inconsistencies
- Application errors
- Database errors

**Recovery Steps:**

1. **Identify Corruption Point**
   ```bash
   # Check database logs
   aws rds describe-db-log-files \
     --db-instance-identifier titanic-api-prod-db \
     --region eu-west-2
   ```

2. **Restore to Point Before Corruption**
   ```bash
   # Use PITR to restore to known good point
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier titanic-api-prod-db \
     --target-db-instance-identifier titanic-api-prod-db-restored \
     --restore-time <time-before-corruption> \
     --region eu-west-2
   ```

3. **Verify Data Integrity**
   ```bash
   # Connect to restored database and verify
   psql -h <restored-endpoint> -U <user> -d <database>
   ```

4. **Switch Application to Restored Database**
   ```bash
   # Update endpoint in Secrets Manager
   aws secretsmanager update-secret \
     --secret-id titanic-api-prod-rds-credentials \
     --secret-string '{"postgres-rds-endpoint": "restored-endpoint.rds.amazonaws.com"}'
   ```

**Expected RTO**: 30-60 minutes

## Failover Procedures

### Automatic Failover (Multi-AZ RDS)

**When It Occurs:**
- Primary database instance failure
- Availability zone failure
- Network connectivity issues

**What Happens:**
1. RDS detects primary failure
2. Automatically promotes standby replica
3. Updates DNS endpoint
4. Application reconnects automatically

**RTO**: ~2 minutes

**No Manual Intervention Required**

### Manual Failover

**When to Use:**
- Planned maintenance
- Testing failover procedures
- Regional migration

**Steps:**

1. **Initiate Manual Failover**
   ```bash
   aws rds reboot-db-instance \
     --db-instance-identifier titanic-api-prod-db \
     --force-failover \
     --region eu-west-2
   ```

2. **Monitor Failover**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db \
     --region eu-west-2 \
     --query 'DBInstances[0].DBInstanceStatus'
   ```

3. **Verify Application**
   ```bash
   curl https://titanic-api.iyere.site/health
   ```

**RTO**: ~5 minutes

## Recovery Testing

### Regular Testing Schedule

**Monthly:**
- Test database restore from backup
- Verify backup integrity
- Test application rollback

**Quarterly:**
- Full disaster recovery drill
- Test failover procedures
- Test cross-region recovery

**Annually:**
- Complete disaster recovery exercise
- Review and update procedures
- Train team on procedures

### Testing Checklist

- [ ] Database backup restore
- [ ] Point-in-time recovery
- [ ] Application rollback
- [ ] Infrastructure restoration
- [ ] Failover procedures
- [ ] Cross-region recovery
- [ ] Documentation accuracy

## Communication Plan

### During Disaster

1. **Immediate Actions**
   - Notify team via Slack/email
   - Create incident ticket
   - Assess severity and impact

2. **Status Updates**
   - Provide updates every 15 minutes
   - Document recovery steps
   - Communicate ETA for resolution

3. **Post-Incident**
   - Conduct post-mortem
   - Document lessons learned
   - Update procedures if needed

## References

- [AWS RDS Disaster Recovery](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiRegionMultiAZ.html)
- [EKS Disaster Recovery](https://aws.amazon.com/blogs/containers/implementing-disaster-recovery-for-amazon-eks/)
- [Terraform State Recovery](https://www.terraform.io/docs/language/state/index.html)
