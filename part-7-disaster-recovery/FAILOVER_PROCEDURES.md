# Failover Procedures

## Overview

This document provides detailed failover procedures for various failure scenarios, including automatic and manual failover processes.

## Failover Types

### 1. Automatic Failover (Multi-AZ RDS)

**When It Occurs:**
- Primary database instance failure
- Availability zone failure
- Network connectivity issues
- Storage failure

**Process:**
1. RDS detects primary failure
2. Automatically promotes standby replica
3. Updates DNS endpoint (same endpoint)
4. Application reconnects automatically

**RTO**: ~2 minutes

**No Manual Intervention Required**

**Monitoring:**
```bash
# Check failover events
aws rds describe-events \
  --source-identifier titanic-api-prod-db \
  --source-type db-instance \
  --region eu-west-2 \
  --max-items 10
```

### 2. Manual Failover (Planned)

**When to Use:**
- Planned maintenance
- Testing failover procedures
- Performance optimization
- Regional migration

**Steps:**

1. **Initiate Manual Failover**
   ```bash
   aws rds reboot-db-instance \
     --db-instance-identifier titanic-api-prod-db \
     --force-failover \
     --region eu-west-2
   ```

2. **Monitor Failover Progress**
   ```bash
   # Watch instance status
   watch -n 5 'aws rds describe-db-instances \
     --db-instance-identifier titanic-api-prod-db \
     --region eu-west-2 \
     --query "DBInstances[0].[DBInstanceStatus,AvailabilityZone,MultiAZ]" \
     --output table'
   ```

3. **Verify Application Connectivity**
   ```bash
   # Check application health
   curl https://titanic-api.iyere.site/health
   
   # Check database connectivity from pod
   kubectl exec -n titanic-api-prod <pod-name> -- \
     psql $DATABASE_URL -c "SELECT 1"
   ```

4. **Verify Data Integrity**
   ```bash
   # Check recent data
   kubectl exec -n titanic-api-prod <pod-name> -- \
     psql $DATABASE_URL -c "SELECT COUNT(*) FROM people"
   ```

**Expected RTO**: ~5 minutes (including verification)

### 3. Application Failover (Rollback)

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
   curl https://titanic-api.iyere.site/health
   curl https://titanic-api.iyere.site/people
   ```

**Expected RTO**: 5-10 minutes

### 4. Regional Failover

**When to Use:**
- Entire AWS region unavailable
- Regional disaster
- Planned regional migration

**Prerequisites:**
- Secondary region infrastructure deployed
- Cross-region database replication configured
- Route53 DNS configuration

**Steps:**

1. **Promote Read Replica (if exists)**
   ```bash
   aws rds promote-read-replica \
     --db-instance-identifier titanic-api-prod-dr \
     --region us-east-1
   ```

2. **Update Route53 DNS**
   ```bash
   # Create failover record set
   cat > failover-to-secondary.json << EOF
   {
     "Changes": [{
       "Action": "UPSERT",
       "ResourceRecordSet": {
         "Name": "titanic-api.iyere.site",
         "Type": "A",
         "AliasTarget": {
           "HostedZoneId": "<secondary-region-alb-zone-id>",
           "DNSName": "<secondary-region-alb-dns>",
           "EvaluateTargetHealth": true
         }
       }
     }]
   }
   EOF
   
   aws route53 change-resource-record-sets \
     --hosted-zone-id <zone-id> \
     --change-batch file://failover-to-secondary.json
   ```

3. **Scale Up Secondary Region**
   ```bash
   # Update kubeconfig for secondary region
   aws eks update-kubeconfig --name titanic-api-prod-dr --region us-east-1
   
   # Scale up application
   kubectl scale deployment titanic-api-prod -n titanic-api-prod --replicas=5
   ```

4. **Update Database Endpoint**
   ```bash
   # Update endpoint in Secrets Manager
   aws secretsmanager update-secret \
     --secret-id titanic-api-prod-rds-credentials \
     --secret-string '{"postgres-rds-endpoint": "<promoted-replica-endpoint>"}' \
     --region us-east-1
   ```

5. **Verify Traffic Routing**
   ```bash
   # Check DNS propagation
   dig titanic-api.iyere.site
   
   # Verify application in secondary region
   curl https://titanic-api.iyere.site/health
   ```

**Expected RTO**: 1-2 hours

## Failover Decision Tree

```
Disaster Detected
    │
    ├─ Database Failure?
    │   ├─ Yes → Multi-AZ? → Yes → Automatic Failover (2 min)
    │   │                        └─ No → Restore from Backup (30 min)
    │   └─ No → Continue
    │
    ├─ Application Failure?
    │   ├─ Yes → Rollback Deployment (10 min)
    │   └─ No → Continue
    │
    ├─ Infrastructure Failure?
    │   ├─ Yes → Regional? → Yes → Regional Failover (1-2 hours)
    │   │                    └─ No → Restore Infrastructure (1 hour)
    │   └─ No → Continue
    │
    └─ Data Corruption?
        └─ Yes → Point-in-Time Recovery (30-60 min)
```

## Failover Testing

### Regular Testing Schedule

**Monthly:**
- Test manual database failover
- Test application rollback
- Verify failover procedures

**Quarterly:**
- Full regional failover test
- Measure actual RTO
- Document lessons learned

**Annually:**
- Complete disaster recovery exercise
- Test all failover scenarios
- Update procedures

### Testing Checklist

- [ ] Database automatic failover (Multi-AZ)
- [ ] Database manual failover
- [ ] Application rollback
- [ ] Regional failover (if configured)
- [ ] DNS failover (Route53)
- [ ] Data integrity verification
- [ ] Application functionality verification

## Failover Monitoring

### Pre-Failover Monitoring

**Metrics to Monitor:**
- Database instance health
- Application pod health
- Network connectivity
- Resource utilization

**Alerts:**
- Database instance status changes
- Application pod crashes
- Health check failures

### During Failover Monitoring

**Metrics to Monitor:**
- Failover progress
- Application reconnection
- Data synchronization
- Performance metrics

**Alerts:**
- Failover completion
- Application recovery
- Data integrity issues

### Post-Failover Monitoring

**Metrics to Monitor:**
- Application performance
- Database performance
- Error rates
- User impact

**Alerts:**
- Performance degradation
- Increased error rates
- Data inconsistencies

## Failover Communication

### During Failover

1. **Immediate Notification**
   - Alert team via Slack/email
   - Create incident ticket
   - Notify stakeholders

2. **Status Updates**
   - Provide updates every 5 minutes
   - Document failover steps
   - Communicate ETA

3. **Post-Failover**
   - Verify service restoration
   - Document failover duration
   - Conduct post-mortem

## Failover Best Practices

### Do's ✅
- Test failover procedures regularly
- Monitor failover events
- Document all failover steps
- Verify data integrity after failover
- Communicate during failover
- Review and improve procedures

### Don'ts ❌
- Don't skip failover testing
- Don't ignore failover alerts
- Don't failover without verification
- Don't skip post-failover review
- Don't forget to update documentation

## References

- [AWS RDS Failover](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
- [Route53 Failover](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html#routing-policy-failover)
- [EKS Disaster Recovery](https://aws.amazon.com/blogs/containers/implementing-disaster-recovery-for-amazon-eks/)
