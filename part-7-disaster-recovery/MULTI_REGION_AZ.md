# Multi-Region and Multi-AZ Strategy

## Overview

This document outlines the multi-region and multi-availability zone (AZ) strategy for the Titanic API infrastructure, ensuring high availability and disaster recovery capabilities.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│              Primary Region: eu-west-2                       │
├─────────────────────────────────────────────────────────────┤
│ EKS Cluster (Multi-AZ)                                     │
│   ├─ AZ: eu-west-2a (Nodes)                                │
│   ├─ AZ: eu-west-2b (Nodes)                                │
│   └─ AZ: eu-west-2c (Nodes)                                 │
│                                                              │
│ RDS Database (Multi-AZ)                                    │
│   ├─ Primary: eu-west-2a                                    │
│   └─ Standby: eu-west-2b (Automatic Failover)              │
│                                                              │
│ Application Pods (Distributed across AZs)                  │
│   └─ Pod Disruption Budget ensures availability             │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ (Optional Cross-Region Replication)
                          │
┌─────────────────────────────────────────────────────────────┐
│          Secondary Region: us-east-1 (DR)                   │
├─────────────────────────────────────────────────────────────┤
│ EKS Cluster (Standby/Minimal)                              │
│   └─ Can be scaled up on failover                          │
│                                                              │
│ RDS Read Replica (Cross-Region)                            │
│   └─ Can be promoted to primary                            │
│                                                              │
│ Application (Standby)                                      │
│   └─ Deployed on failover                                   │
└─────────────────────────────────────────────────────────────┘
```

## Multi-AZ Strategy (Primary Region)

### EKS Cluster Multi-AZ

**Configuration:**
- Cluster deployed across 3 availability zones
- Node groups distributed across AZs
- Karpenter automatically distributes nodes across AZs

**Benefits:**
- High availability (survives single AZ failure)
- Load distribution
- Reduced latency (nodes closer to users)

**Implementation:**
```hcl
# In EKS module
subnet_ids = [
  var.public_subnet_ids,   # Across multiple AZs
  var.private_subnet_ids   # Across multiple AZs
]
```

### RDS Multi-AZ

**Configuration:**
- Primary instance in one AZ
- Standby replica in different AZ
- Automatic synchronous replication
- Automatic failover (~2 minutes)

**Benefits:**
- Zero data loss (synchronous replication)
- Automatic failover
- High availability

**Failover Process:**
1. Primary instance fails
2. RDS detects failure
3. Automatically promotes standby
4. Updates DNS endpoint
5. Application reconnects automatically

**RTO**: ~2 minutes

### Application Pod Distribution

**Configuration:**
- Pods distributed across nodes in different AZs
- Pod Disruption Budget ensures minimum availability
- Anti-affinity rules (optional) prevent pod co-location

**Benefits:**
- Survives single AZ failure
- Load balancing across AZs
- Better performance

**Implementation:**
```yaml
# Pod Disruption Budget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: titanic-api-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: titanic-api
```

## Multi-Region Strategy (Optional)

### Active-Standby Configuration

**Primary Region (eu-west-2):**
- Full infrastructure running
- Active traffic
- Primary RDS instance
- Full EKS cluster

**Secondary Region (us-east-1):**
- Minimal infrastructure (cost optimization)
- RDS cross-region read replica
- Standby EKS cluster (can be minimal)
- Traffic routed only on failover

**Benefits:**
- Lower cost (secondary region minimal)
- Data replicated for DR
- Fast failover capability
- Regional disaster protection

**Cost**: ~1.2x primary region cost (vs 2x for active-active)

### Active-Active Configuration

**Both Regions:**
- Full infrastructure in both regions
- Traffic split between regions (Route53 weighted routing)
- RDS primary in one region, read replica in other
- Active workloads in both regions

**Benefits:**
- Zero-downtime failover
- Geographic distribution
- Higher availability
- Load distribution

**Cost**: ~2x infrastructure cost

**Use Case**: High-traffic, globally distributed applications

## Availability Zone Distribution

### Current Configuration

**EKS Cluster:**
- Subnets in 3 availability zones
- Nodes automatically distributed by Karpenter
- Load balancers span all AZs

**RDS Database:**
- Primary: eu-west-2a
- Standby: eu-west-2b
- Automatic failover between AZs

**Application:**
- Pods distributed across all AZs
- Service endpoints span all AZs
- Ingress controller in all AZs

### AZ Failure Scenarios

**Single AZ Failure:**
- EKS: Survives (nodes in other AZs)
- RDS: Automatic failover to standby AZ
- Application: Continues running (pods in other AZs)
- **Impact**: Minimal (automatic recovery)

**Two AZ Failure:**
- EKS: May have reduced capacity
- RDS: Standby in remaining AZ (if available)
- Application: Reduced capacity
- **Impact**: Service degradation, manual intervention may be needed

**All AZ Failure (Regional):**
- Requires multi-region failover
- **Impact**: Regional disaster recovery

## Cross-Region Replication

### Database Replication

**Configuration:**
- Cross-region read replica (async replication)
- Replication lag: < 5 minutes typically
- Can be promoted to primary

**Setup:**
```bash
# Create cross-region read replica
aws rds create-db-instance-read-replica \
  --db-instance-identifier titanic-api-prod-dr \
  --source-db-instance-identifier titanic-api-prod-db \
  --db-instance-class db.t3.medium \
  --region us-east-1 \
  --source-region eu-west-2
```

**Promotion:**
```bash
# Promote read replica to primary
aws rds promote-read-replica \
  --db-instance-identifier titanic-api-prod-dr \
  --region us-east-1
```

**RPO**: < 5 minutes (replication lag)

### Backup Replication

**Configuration:**
- Automated backups replicated to secondary region
- Manual snapshots can be copied
- Enables fast recovery in secondary region

**Setup:**
```bash
# Copy snapshot to secondary region
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier titanic-api-prod-snapshot \
  --target-db-snapshot-identifier titanic-api-prod-dr-snapshot \
  --source-region eu-west-2 \
  --target-region us-east-1
```

## Failover Procedures

### Multi-AZ Failover (Automatic)

**When It Occurs:**
- Primary database instance failure
- Availability zone failure
- Network connectivity issues

**Process:**
1. RDS detects failure
2. Automatically promotes standby
3. Updates DNS endpoint
4. Application reconnects

**RTO**: ~2 minutes

**No Manual Intervention Required**

### Cross-Region Failover (Manual)

**When to Use:**
- Entire region unavailable
- Regional disaster
- Planned migration

**Steps:**

1. **Promote Read Replica**
   ```bash
   aws rds promote-read-replica \
     --db-instance-identifier titanic-api-prod-dr \
     --region us-east-1
   ```

2. **Update Route53 DNS**
   ```bash
   # Update DNS to point to secondary region
   aws route53 change-resource-record-sets \
     --hosted-zone-id <zone-id> \
     --change-batch file://failover-to-secondary.json
   ```

3. **Scale Up Secondary Region**
   ```bash
   # Update kubeconfig
   aws eks update-kubeconfig --name titanic-api-prod-dr --region us-east-1
   
   # Scale up application
   kubectl scale deployment titanic-api-prod -n titanic-api-prod --replicas=5
   ```

4. **Update Application Configuration**
   ```bash
   # Update database endpoint
   aws secretsmanager update-secret \
     --secret-id titanic-api-prod-rds-credentials \
     --secret-string '{"postgres-rds-endpoint": "<promoted-replica-endpoint>"}' \
     --region us-east-1
   ```

**RTO**: 1-2 hours

## Cost Analysis

### Multi-AZ Costs

**EKS:**
- No additional cost (nodes distributed automatically)
- Same number of nodes, just distributed

**RDS:**
- ~2x storage cost (primary + standby)
- Same compute cost (standby doesn't process queries)
- **Additional Cost**: ~$50-100/month (storage)

### Multi-Region Costs

**Active-Standby:**
- Secondary region: ~20% of primary (minimal infrastructure)
- Cross-region replication: ~$20/month
- **Total Additional**: ~$200-300/month

**Active-Active:**
- Secondary region: ~100% of primary
- Cross-region replication: ~$20/month
- **Total Additional**: ~$1000-1500/month

## Monitoring and Alerting

### Multi-AZ Monitoring

**Metrics:**
- Database failover events
- Node distribution across AZs
- Pod distribution across AZs
- Cross-AZ latency

**Alerts:**
- Database failover occurred
- Uneven node distribution
- Single AZ pod concentration

### Multi-Region Monitoring

**Metrics:**
- Replication lag
- Regional health
- Cross-region latency
- Failover readiness

**Alerts:**
- Replication lag > 5 minutes
- Regional health check failures
- Failover readiness issues

## Best Practices

### Multi-AZ ✅
- Always use Multi-AZ for production RDS
- Distribute EKS nodes across AZs
- Use Pod Disruption Budgets
- Monitor AZ distribution

### Multi-Region ✅
- Use active-standby for cost optimization
- Use active-active for high availability
- Test failover procedures regularly
- Monitor replication lag
- Keep secondary region ready

### Don'ts ❌
- Don't deploy single-AZ in production
- Don't ignore replication lag
- Don't skip failover testing
- Don't forget to update DNS on failover

## References

- [AWS RDS Multi-AZ](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
- [EKS Multi-AZ](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html)
- [Cross-Region Replication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.XRgn.html)
