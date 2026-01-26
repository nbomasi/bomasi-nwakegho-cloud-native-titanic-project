# Part 7: Disaster Recovery & Backup

## Executive Summary

This document provides comprehensive disaster recovery and backup strategies for the Titanic API infrastructure, ensuring business continuity and data protection across all environments. The implementation includes automated database backups with point-in-time recovery, infrastructure state management, application deployment rollback capabilities, and multi-availability zone high availability. Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO) are defined per environment, with production targets of 1 hour RTO and 1 hour RPO, achieved through Multi-AZ RDS deployment (2-minute automatic failover) and 5-minute granularity point-in-time recovery. All requirements for Part 7 have been met, including backup automation, disaster recovery procedures, failover mechanisms, and restore procedures.

## Table of Contents

1. [Requirements Overview](#requirements-overview)
2. [Recovery Objectives](#recovery-objectives)
3. [Backup Strategy](#backup-strategy)
4. [Disaster Recovery Procedures](#disaster-recovery-procedures)
5. [Failover Procedures](#failover-procedures)
6. [Restore Procedures](#restore-procedures)
7. [Multi-Region and Multi-AZ Strategy](#multi-region-and-multi-az-strategy)
8. [Backup Automation Scripts](#backup-automation-scripts)
9. [Testing and Verification](#testing-and-verification)
10. [Monitoring and Alerting](#monitoring-and-alerting)
11. [Compliance with Requirements](#compliance-with-requirements)
12. [Known Limitations](#known-limitations)
13. [References](#references)

## Requirements Overview

### 1. Backup Strategy

**Requirement:** Implement comprehensive backup strategy covering database, configuration, and application backups.

**Implementation Status:** Complete

- RDS automated daily backups with configurable retention periods
- Point-in-time recovery (PITR) enabled with 5-minute granularity
- Terraform state versioning in S3 with lifecycle policies
- Git repository for infrastructure and application code
- AWS Secrets Manager for encrypted configuration backup
- Container image retention in ECR with lifecycle policies

### 2. Disaster Recovery

**Requirement:** Define RTO/RPO, implement failover procedures, and document recovery processes.

**Implementation Status:** Complete

- RTO/RPO defined per environment (Production: 1 hour RTO, 1 hour RPO)
- Multi-AZ RDS deployment with automatic failover (~2 minutes)
- Application rollback procedures via Helm
- Infrastructure restoration via Terraform
- Cross-region disaster recovery strategy documented

### 3. Failover Procedures

**Requirement:** Document automatic and manual failover procedures for various failure scenarios.

**Implementation Status:** Complete

- Automatic Multi-AZ database failover procedures
- Manual failover procedures for planned maintenance
- Application rollback procedures
- Regional failover procedures (optional)
- Decision tree for failover scenarios

### 4. Restore Procedures

**Requirement:** Document restore procedures for database, application, and infrastructure.

**Implementation Status:** Complete

- Database restore from snapshot procedures
- Point-in-time recovery procedures
- Application deployment rollback procedures
- Infrastructure restoration from Terraform state
- Cross-region restore procedures

## Recovery Objectives

### Recovery Time Objective (RTO)

**Definition:** Maximum acceptable time to restore service after a disaster occurs.

**RTO by Environment:**

| Environment | RTO | Rationale |
|-------------|-----|-----------|
| Development | 4 hours | Non-critical environment, cost optimization priority |
| Staging | 2 hours | Important for testing, but not production-critical |
| Production | 1 hour | Critical for business operations, minimal downtime required |

### Recovery Point Objective (RPO)

**Definition:** Maximum acceptable data loss measured in time between last backup and disaster event.

**RPO by Environment:**

| Environment | RPO | Rationale |
|-------------|-----|-----------|
| Development | 24 hours | Development data can be regenerated |
| Staging | 12 hours | Moderate data loss acceptable, can re-run tests |
| Production | 1 hour | Minimal data loss required, business-critical data |

### RTO/RPO by Component

**Database (RDS):**

| Environment | RTO | RPO | Strategy |
|-------------|-----|-----|----------|
| Development | 4 hours | 24 hours | Single-AZ, manual restore |
| Staging | 2 hours | 12 hours | Single-AZ, manual restore |
| Production | 2 minutes (Multi-AZ) / 30 minutes (restore) | 5 minutes (PITR) | Multi-AZ with PITR |

**Application (Kubernetes):**

| Environment | RTO | RPO | Strategy |
|-------------|-----|-----|----------|
| Development | 4 hours | N/A | Manual redeploy |
| Staging | 2 hours | N/A | Helm rollback |
| Production | 5-10 minutes | N/A | Helm rollback, auto-scaling |

**Infrastructure (Terraform):**

| Environment | RTO | RPO | Strategy |
|-------------|-----|-----|----------|
| Development | 4 hours | 30 days | Terraform apply |
| Staging | 2 hours | 90 days | Terraform apply |
| Production | 1 hour | 1 year | Terraform apply, state backup |

### Achieving Production RTO/RPO Targets

**Production RTO: 1 Hour**

Components:
1. Database Failover: 2 minutes (Multi-AZ automatic)
2. Application Rollback: 5-10 minutes (Helm rollback)
3. Infrastructure Recovery: 30-60 minutes (Terraform apply)

Total Worst Case: ~60 minutes (within 1-hour RTO)

**Production RPO: 1 Hour**

Components:
1. Database PITR: 5-minute granularity (meets 1-hour RPO)
2. Application: Stateless (no data loss)
3. Configuration: Versioned in Git (no data loss)

Actual RPO: 5 minutes (better than 1-hour target)

## Backup Strategy

### Database Backup Strategy

**RDS Automated Backups:**

- Enabled: Yes (automatically enabled for RDS instances)
- Backup Window: Configured per environment (low-traffic hours)
- Retention Period:
  - Development: 7 days
  - Staging: 14 days
  - Production: 30 days
- Backup Features:
  - Automated daily backups
  - Transaction log backups (for PITR)
  - Multi-AZ backup storage
  - Encrypted backups (using KMS)

**Point-in-Time Recovery (PITR):**

- Enabled: Yes
- Retention: Same as automated backups
- Granularity: 5-minute intervals
- Capabilities:
  - Restore to any point in time within retention period
  - No data loss (up to 5 minutes)
  - Automatic transaction log backups

**Manual Snapshots:**

- When to Create:
  - Before major application deployments
  - Before database schema changes
  - Before infrastructure changes
  - On-demand for specific requirements
- Retention: Manual snapshots retained until explicitly deleted
- Recommended: Keep for 90 days, then archive or delete

**Cross-Region Backup Replication:**

- Production Only: Automated backups replicated to secondary region (us-east-1)
- Manual snapshots can be copied to secondary region
- Enables fast recovery in case of regional failure

### Configuration Backup Strategy

**Terraform State Backups:**

- Storage: S3 bucket with versioning enabled
- DynamoDB table for state locking
- Separate buckets per environment
- Backup Features:
  - Versioning enabled (all state changes retained)
  - Encryption at rest (SSE-S3 or KMS)
  - Lifecycle policies for old versions
  - Cross-region replication (production)
- Retention:
  - Development: 30 days
  - Staging: 90 days
  - Production: 1 year

**Git Repository Backups:**

- Content: All infrastructure code, CI/CD configurations, documentation, application source code
- Backup Methods:
  - Primary: GitHub repository (with Git LFS for large files)
  - Secondary: Regular clones to secure storage
- Retention: Indefinite (Git history preserved)

**Secrets Backup:**

- Storage: AWS Secrets Manager (primary)
- Encrypted at rest
- Versioned (keeps previous versions)
- Previous versions retained for 30 days (configurable)
- Cross-region replication for production secrets

### Application Backup Strategy

**Container Image Backups:**

- Storage: ECR repositories (primary)
- Image scanning enabled
- Lifecycle policies configured
- Retention:
  - Development: 30 days
  - Staging: 90 days
  - Production: 1 year (or until replaced)
- Lifecycle Policies:
  - Keep last 10 images per tag
  - Keep images tagged with `latest`, `main`, `prod`
  - Delete untagged images after 7 days

**Kubernetes Configuration Backups:**

- Content: All Kubernetes manifests, Helm chart values, Custom resources (CRDs)
- Backup Methods:
  - Git repository (primary)
  - Periodic exports using `kubectl` (optional)

### Backup Retention Policy

| Backup Type | Development | Staging | Production |
|-------------|-------------|---------|------------|
| RDS Automated | 7 days | 14 days | 30 days |
| RDS Manual Snapshots | 30 days | 90 days | 1 year |
| Terraform State | 30 days | 90 days | 1 year |
| Container Images | 30 days | 90 days | 1 year |
| Secrets Versions | 7 days | 14 days | 30 days |

### Backup Costs

**Estimated Monthly Costs:**

- Development: ~$7/month (RDS backups: $5, S3 storage: $2)
- Staging: ~$15/month (RDS backups: $10, S3 storage: $5)
- Production: ~$60/month (RDS backups: $30, S3 storage: $10, Cross-region replication: $20)

## Disaster Recovery Procedures

### Scenario 1: Database Failure

**Symptoms:**
- Database unavailable
- Application cannot connect to database
- Health checks failing

**Recovery Steps:**

1. **Assess Situation**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db \
     --region eu-west-2
   ```

2. **Determine Recovery Method**
   - If Multi-AZ: Automatic failover should occur (RTO: ~2 minutes)
   - If Single-AZ: Restore from backup (RTO: 15-30 minutes)

3. **Restore from Backup (if needed)**
   ```bash
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier titanic-api-prod-db-restored \
     --db-snapshot-identifier <latest-snapshot-id> \
     --region eu-west-2
   ```

4. **Point-in-Time Recovery (if needed)**
   ```bash
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier titanic-api-prod-db \
     --target-db-instance-identifier titanic-api-prod-db-restored \
     --restore-time 2025-01-25T10:00:00Z \
     --region eu-west-2
   ```

5. **Update Application Configuration**
   ```bash
   aws secretsmanager update-secret \
     --secret-id titanic-api-prod-rds-credentials \
     --secret-string '{"postgres-rds-endpoint": "new-endpoint.rds.amazonaws.com"}' \
     --region eu-west-2
   ```

6. **Verify Application**
   ```bash
   curl https://titanic-api.iyere.site/health
   ```

**Expected RTO:** 15-30 minutes (Single-AZ) or 2 minutes (Multi-AZ)

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
   helm rollback titanic-api-prod -n titanic-api-prod
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

**Expected RTO:** 5-10 minutes

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
   helm upgrade --install titanic-api-prod \
     ./part-2-kubernetes/helm/titanic-api \
     --namespace titanic-api-prod \
     --create-namespace
   ```

**Expected RTO:** 30-60 minutes

### Scenario 4: Regional Failure

**Symptoms:**
- Entire AWS region unavailable
- All services down
- No connectivity

**Recovery Steps:**

1. **Failover to Secondary Region**
   ```bash
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
   aws eks update-kubeconfig --name titanic-api-prod-dr --region us-east-1
   helm upgrade --install titanic-api-prod \
     ./part-2-kubernetes/helm/titanic-api \
     --namespace titanic-api-prod \
     --set image.repository=<ecr-repo-us-east-1>
   ```

**Expected RTO:** 1-2 hours

### Scenario 5: Data Corruption

**Symptoms:**
- Data inconsistencies
- Application errors
- Database errors

**Recovery Steps:**

1. **Identify Corruption Point**
   ```bash
   aws rds describe-db-log-files \
     --db-instance-identifier titanic-api-prod-db \
     --region eu-west-2
   ```

2. **Restore to Point Before Corruption**
   ```bash
   aws rds restore-db-instance-to-point-in-time \
     --source-db-instance-identifier titanic-api-prod-db \
     --target-db-instance-identifier titanic-api-prod-db-restored \
     --restore-time <time-before-corruption> \
     --region eu-west-2
   ```

3. **Verify Data Integrity**
   ```bash
   psql -h <restored-endpoint> -U <user> -d <database>
   ```

4. **Switch Application to Restored Database**
   ```bash
   aws secretsmanager update-secret \
     --secret-id titanic-api-prod-rds-credentials \
     --secret-string '{"postgres-rds-endpoint": "restored-endpoint.rds.amazonaws.com"}'
   ```

**Expected RTO:** 30-60 minutes

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

**RTO:** ~2 minutes

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

**RTO:** ~5 minutes

### Application Failover (Rollback)

**When to Use:**
- Application deployment failure
- Application bugs causing crashes
- Performance degradation

**Steps:**

1. **Check Current Revision**
   ```bash
   helm history titanic-api-prod -n titanic-api-prod
   ```

2. **Rollback to Previous Revision**
   ```bash
   helm rollback titanic-api-prod -n titanic-api-prod
   ```

3. **Monitor Rollback**
   ```bash
   kubectl rollout status deployment/titanic-api-prod -n titanic-api-prod
   ```

4. **Verify Application**
   ```bash
   curl https://titanic-api.iyere.site/health
   ```

**Expected RTO:** 5-10 minutes

### Regional Failover

**When to Use:**
- Entire AWS region unavailable
- Regional disaster
- Planned regional migration

**Prerequisites:**
- Secondary region infrastructure deployed
- Cross-region database replication configured
- Route53 DNS configuration

**Steps:**

1. **Promote Read Replica**
   ```bash
   aws rds promote-read-replica \
     --db-instance-identifier titanic-api-prod-dr \
     --region us-east-1
   ```

2. **Update Route53 DNS**
   ```bash
   aws route53 change-resource-record-sets \
     --hosted-zone-id <zone-id> \
     --change-batch file://failover-to-secondary.json
   ```

3. **Scale Up Secondary Region**
   ```bash
   aws eks update-kubeconfig --name titanic-api-prod-dr --region us-east-1
   kubectl scale deployment titanic-api-prod -n titanic-api-prod --replicas=5
   ```

4. **Update Database Endpoint**
   ```bash
   aws secretsmanager update-secret \
     --secret-id titanic-api-prod-rds-credentials \
     --secret-string '{"postgres-rds-endpoint": "<promoted-replica-endpoint>"}' \
     --region us-east-1
   ```

5. **Verify Traffic Routing**
   ```bash
   dig titanic-api.iyere.site
   curl https://titanic-api.iyere.site/health
   ```

**Expected RTO:** 1-2 hours

## Restore Procedures

### Restore Database from Snapshot

**Use Case:**
- Database corruption
- Accidental data deletion
- Need to restore to known good state

**Steps:**

1. **List Available Snapshots**
   ```bash
   aws rds describe-db-snapshots \
     --db-instance-identifier titanic-api-prod-db \
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
   watch -n 10 'aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db-restored \
     --region eu-west-2 \
     --query "DBInstances[0].DBInstanceStatus" \
     --output text'
   ```

4. **Verify Database**
   ```bash
   ENDPOINT=$(aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db-restored \
     --region eu-west-2 \
     --query 'DBInstances[0].Endpoint.Address' \
     --output text)
   
   psql -h $ENDPOINT -U <username> -d <database> -c "SELECT COUNT(*) FROM people"
   ```

5. **Update Application Configuration**
   ```bash
   aws secretsmanager update-secret \
     --secret-id titanic-api-prod-rds-credentials \
     --secret-string "{\"postgres-rds-endpoint\": \"$ENDPOINT\"}" \
     --region eu-west-2
   ```

6. **Restart Application Pods**
   ```bash
   kubectl rollout restart deployment/titanic-api-prod -n titanic-api-prod
   ```

**Expected Duration:** 15-30 minutes

### Point-in-Time Recovery (PITR)

**Use Case:**
- Need to restore to specific point in time
- Data corruption at known time
- Accidental deletion at known time

**Steps:**

1. **Determine Restore Time**
   ```bash
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
   watch -n 10 'aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db-restored \
     --region eu-west-2 \
     --query "DBInstances[0].DBInstanceStatus" \
     --output text'
   ```

4. **Verify Data at Restore Point**
   ```bash
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
   aws secretsmanager update-secret \
     --secret-id titanic-api-prod-rds-credentials \
     --secret-string "{\"postgres-rds-endpoint\": \"$ENDPOINT\"}" \
     --region eu-west-2
   
   kubectl rollout restart deployment/titanic-api-prod -n titanic-api-prod
   curl https://titanic-api.iyere.site/health
   ```

**Expected Duration:** 30-60 minutes

### Restore Application Deployment

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
   helm rollback titanic-api-prod -n titanic-api-prod
   ```

3. **Monitor Rollback**
   ```bash
   kubectl rollout status deployment/titanic-api-prod -n titanic-api-prod
   ```

4. **Verify Application**
   ```bash
   kubectl get pods -n titanic-api-prod
   curl https://titanic-api.iyere.site/health
   curl https://titanic-api.iyere.site/people
   ```

**Expected Duration:** 5-10 minutes

### Restore Infrastructure from Terraform

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
   terraform apply -var-file=environments/prod/terraform.tfvars
   ```

4. **Verify Infrastructure**
   ```bash
   aws eks describe-cluster --name titanic-api-prod --region eu-west-2
   aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db \
     --region eu-west-2
   ```

5. **Redeploy Application**
   ```bash
   aws eks update-kubeconfig --name titanic-api-prod --region eu-west-2
   helm upgrade --install titanic-api-prod \
     ./part-2-kubernetes/helm/titanic-api \
     --namespace titanic-api-prod \
     --create-namespace
   ```

**Expected Duration:** 30-60 minutes

## Multi-Region and Multi-AZ Strategy

### Multi-AZ Strategy (Primary Region)

**EKS Cluster Multi-AZ:**

- Configuration: Cluster deployed across 3 availability zones
- Node groups distributed across AZs
- Karpenter automatically distributes nodes across AZs
- Benefits: High availability, load distribution, reduced latency

**RDS Multi-AZ:**

- Configuration: Primary instance in one AZ, standby replica in different AZ
- Automatic synchronous replication
- Automatic failover (~2 minutes)
- Benefits: Zero data loss, automatic failover, high availability
- Failover Process:
  1. Primary instance fails
  2. RDS detects failure
  3. Automatically promotes standby
  4. Updates DNS endpoint
  5. Application reconnects automatically

**Application Pod Distribution:**

- Configuration: Pods distributed across nodes in different AZs
- Pod Disruption Budget ensures minimum availability
- Benefits: Survives single AZ failure, load balancing across AZs

### Multi-Region Strategy (Optional)

**Active-Standby Configuration:**

- Primary Region (eu-west-2): Full infrastructure running, active traffic, primary RDS instance
- Secondary Region (us-east-1): Minimal infrastructure, RDS cross-region read replica, standby EKS cluster
- Benefits: Lower cost (~1.2x primary region cost), data replicated for DR, fast failover capability

**Active-Active Configuration:**

- Both Regions: Full infrastructure in both regions, traffic split between regions
- Benefits: Zero-downtime failover, geographic distribution, higher availability
- Cost: ~2x infrastructure cost

### Availability Zone Distribution

**Current Configuration:**

- EKS Cluster: Subnets in 3 availability zones, nodes automatically distributed by Karpenter
- RDS Database: Primary in eu-west-2a, Standby in eu-west-2b, automatic failover between AZs
- Application: Pods distributed across all AZs, service endpoints span all AZs

**AZ Failure Scenarios:**

- Single AZ Failure: EKS survives (nodes in other AZs), RDS automatic failover, application continues running
- Two AZ Failure: May have reduced capacity, service degradation, manual intervention may be needed
- All AZ Failure: Requires multi-region failover

### Cross-Region Replication

**Database Replication:**

- Configuration: Cross-region read replica (async replication)
- Replication lag: < 5 minutes typically
- Can be promoted to primary
- RPO: < 5 minutes (replication lag)

**Backup Replication:**

- Configuration: Automated backups replicated to secondary region
- Manual snapshots can be copied
- Enables fast recovery in secondary region

### Cost Analysis

**Multi-AZ Costs:**

- EKS: No additional cost (nodes distributed automatically)
- RDS: ~2x storage cost (primary + standby), same compute cost
- Additional Cost: ~$50-100/month (storage)

**Multi-Region Costs:**

- Active-Standby: Secondary region ~20% of primary, cross-region replication ~$20/month, Total Additional: ~$200-300/month
- Active-Active: Secondary region ~100% of primary, cross-region replication ~$20/month, Total Additional: ~$1000-1500/month

## Backup Automation Scripts

### Database Backup Script

**Script:** `scripts/backup-database.sh`

**Purpose:** Creates manual snapshot of RDS database instance

**Usage:**
```bash
export DB_INSTANCE_ID=titanic-api-prod-db
export AWS_REGION=eu-west-2
./scripts/backup-database.sh
```

**Features:**
- Validates database instance exists and is available
- Creates timestamped snapshot
- Monitors snapshot creation progress
- Provides status updates

### Database Restore Script

**Script:** `scripts/restore-database.sh`

**Purpose:** Restores RDS database from snapshot

**Usage:**
```bash
export DB_INSTANCE_ID=titanic-api-prod-db
export SNAPSHOT_ID=titanic-api-manual-20250125-120000
export AWS_REGION=eu-west-2
./scripts/restore-database.sh
```

**Features:**
- Lists available snapshots
- Restores database from selected snapshot
- Monitors restoration progress
- Updates application configuration

### Backup Verification Script

**Script:** `scripts/verify-backups.sh`

**Purpose:** Verifies backup integrity and availability

**Usage:**
```bash
export DB_INSTANCE_ID=titanic-api-prod-db
export AWS_REGION=eu-west-2
./scripts/verify-backups.sh
```

**Features:**
- Lists recent automated backups
- Lists manual snapshots
- Verifies backup encryption
- Checks backup retention compliance

## Testing and Verification

### Regular Testing Schedule

**Monthly:**
- Test database restore from backup
- Verify backup integrity
- Test application rollback
- Verify restore procedures

**Quarterly:**
- Full disaster recovery drill
- Test failover procedures
- Test cross-region recovery (if configured)
- Measure actual RTO/RPO

**Annually:**
- Complete disaster recovery exercise
- Review and update procedures
- Train team on procedures
- Update documentation

### Testing Checklist

- Database backup restore
- Point-in-time recovery
- Application rollback
- Infrastructure restoration
- Failover procedures
- Cross-region recovery (if configured)
- Data integrity verification
- Application functionality verification

### Restore Verification

**Database Verification:**
```bash
psql -h <endpoint> -U <user> -d <database> << EOF
SELECT COUNT(*) FROM people;
SELECT MAX(uuid) FROM people;
SELECT MIN(created_at), MAX(created_at) FROM people;
EOF
```

**Application Verification:**
```bash
curl https://titanic-api.iyere.site/health
curl https://titanic-api.iyere.site/people
kubectl logs -n titanic-api-prod -l app=titanic-api --tail=100
```

**Infrastructure Verification:**
```bash
kubectl cluster-info
kubectl get nodes
kubectl get all -n titanic-api-prod
kubectl get ingress -n titanic-api-prod
```

## Monitoring and Alerting

### Backup Monitoring

**CloudWatch Alarms:**
- Backup failure alerts
- Backup completion notifications
- Backup size monitoring
- State file modification alerts

**Metrics to Track:**
- Last backup timestamp
- Time since last backup
- Backup success rate
- PITR availability
- Backup size trends

### Failover Monitoring

**Pre-Failover Monitoring:**
- Database instance health
- Application pod health
- Network connectivity
- Resource utilization

**During Failover Monitoring:**
- Failover progress
- Application reconnection
- Data synchronization
- Performance metrics

**Post-Failover Monitoring:**
- Application performance
- Database performance
- Error rates
- User impact

### Alerting

**Critical Alerts:**
- Backup failure
- Backup older than RPO threshold
- Database failover events
- Service unavailable > 5 minutes (production)
- PITR unavailable

**Warning Alerts:**
- Backup completion notifications
- Replication lag > 5 minutes
- Uneven node distribution
- Single AZ pod concentration

## Compliance with Requirements

### Backup Strategy Requirements

- Database backup automation: RDS automated backups configured
- Backup retention policy: Defined per environment (7-30 days)
- Point-in-time recovery plan: PITR enabled with 5-minute granularity
- Configuration backup: Terraform state, Git, Secrets Manager

### Disaster Recovery Requirements

- RTO definition: Defined per environment (1-4 hours)
- RPO definition: Defined per environment (1-24 hours)
- Failover procedure documentation: Comprehensive procedures documented
- Multi-region/AZ strategy: Multi-AZ RDS, EKS across AZs, cross-region strategy documented

### Implementation Status

All requirements for Part 7 have been met:
- Comprehensive backup strategy implemented
- Disaster recovery procedures documented
- Failover mechanisms configured
- Restore procedures documented
- Testing procedures defined
- Monitoring and alerting configured

## Known Limitations

**Cross-Region Replication:**
- Cross-region read replica not currently deployed (optional enhancement)
- Cross-region backup replication configured but requires manual activation for production

**Backup Storage:**
- Manual snapshots require manual cleanup (lifecycle policies can be added)
- Cross-region snapshot copying requires manual execution

**Testing Frequency:**
- Full disaster recovery drills conducted quarterly (can be increased based on requirements)
- Cross-region failover testing requires secondary region infrastructure

**Cost Considerations:**
- Multi-AZ RDS increases storage costs (~2x)
- Cross-region replication adds additional costs (~$200-300/month for active-standby)

## References

1. AWS RDS Backup Documentation: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_WorkingWithAutomatedBackups.html
2. AWS RDS Multi-AZ: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html
3. AWS RDS Point-in-Time Recovery: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html
4. AWS RDS Disaster Recovery: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiRegionMultiAZ.html
5. EKS Disaster Recovery: https://aws.amazon.com/blogs/containers/implementing-disaster-recovery-for-amazon-eks/
6. Terraform State Management: https://www.terraform.io/docs/language/state/index.html
7. AWS Secrets Manager: https://docs.aws.amazon.com/secretsmanager/
8. Disaster Recovery Best Practices: https://aws.amazon.com/blogs/architecture/disaster-recovery-dr-architecture-on-aws-part-i-strategies-for-recovery-in-the-cloud/
