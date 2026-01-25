# RTO and RPO Definitions

## Overview

This document defines Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO) for the Titanic API infrastructure across all environments.

## Definitions

### Recovery Time Objective (RTO)

**Definition**: The maximum acceptable time to restore service after a disaster occurs.

**Measurement**: Time from disaster detection to service restoration.

**Factors Considered:**
- Business impact
- Service criticality
- Infrastructure complexity
- Recovery procedures complexity

### Recovery Point Objective (RPO)

**Definition**: The maximum acceptable data loss measured in time.

**Measurement**: Time between the last backup and the disaster event.

**Factors Considered:**
- Data criticality
- Backup frequency
- Data change rate
- Business requirements

## RTO/RPO by Environment

### Development Environment

| Metric | Value | Rationale |
|--------|-------|-----------|
| **RTO** | 4 hours | Non-critical environment, can tolerate longer downtime for cost optimization |
| **RPO** | 24 hours | Development data can be regenerated, significant data loss acceptable |

**Recovery Strategy:**
- Manual recovery procedures
- Standard backup retention (7 days)
- Single-AZ deployment acceptable
- No automated failover required

**Cost Optimization:**
- Lower RTO/RPO requirements allow cost savings
- No need for Multi-AZ or cross-region replication

### Staging Environment

| Metric | Value | Rationale |
|--------|-------|-----------|
| **RTO** | 2 hours | Important for testing, but not production-critical |
| **RPO** | 12 hours | Moderate data loss acceptable, can re-run tests |

**Recovery Strategy:**
- Semi-automated recovery
- Extended backup retention (14 days)
- Single-AZ deployment acceptable
- Manual failover procedures

**Balanced Approach:**
- Better than development but not production-level
- Allows testing of recovery procedures

### Production Environment

| Metric | Value | Rationale |
|--------|-------|-----------|
| **RTO** | 1 hour | Critical for business operations, minimal downtime required |
| **RPO** | 1 hour | Minimal data loss required, business-critical data |

**Recovery Strategy:**
- Automated failover where possible
- Extended backup retention (30 days)
- Multi-AZ deployment required
- Point-in-time recovery enabled
- Cross-region replication (optional)

**High Availability:**
- Multi-AZ RDS (automatic failover ~2 minutes)
- EKS across multiple availability zones
- Automated backups with PITR

## RTO/RPO by Component

### Database (RDS)

| Environment | RTO | RPO | Strategy |
|-------------|-----|-----|----------|
| Development | 4 hours | 24 hours | Single-AZ, manual restore |
| Staging | 2 hours | 12 hours | Single-AZ, manual restore |
| Production | 2 minutes (Multi-AZ) / 30 minutes (restore) | 5 minutes (PITR) | Multi-AZ with PITR |

**Production Database:**
- **Multi-AZ RTO**: ~2 minutes (automatic failover)
- **Restore RTO**: 15-30 minutes (from backup)
- **PITR RPO**: 5 minutes (point-in-time recovery granularity)

### Application (Kubernetes)

| Environment | RTO | RPO | Strategy |
|-------------|-----|-----|----------|
| Development | 4 hours | N/A | Manual redeploy |
| Staging | 2 hours | N/A | Helm rollback |
| Production | 5-10 minutes | N/A | Helm rollback, auto-scaling |

**Production Application:**
- **Rollback RTO**: 5-10 minutes
- **Scale-up RTO**: 2-5 minutes
- **No data loss** (stateless application)

### Infrastructure (Terraform)

| Environment | RTO | RPO | Strategy |
|-------------|-----|-----|----------|
| Development | 4 hours | 30 days | Terraform apply |
| Staging | 2 hours | 90 days | Terraform apply |
| Production | 1 hour | 1 year | Terraform apply, state backup |

**Infrastructure Recovery:**
- **Terraform Apply RTO**: 30-60 minutes
- **State Backup RPO**: Based on S3 versioning retention

## Achieving RTO/RPO Targets

### Production RTO: 1 Hour

**Components:**
1. **Database Failover**: 2 minutes (Multi-AZ automatic)
2. **Application Rollback**: 5-10 minutes (Helm rollback)
3. **Infrastructure Recovery**: 30-60 minutes (Terraform apply)

**Total Worst Case**: ~60 minutes (within 1-hour RTO)

### Production RPO: 1 Hour

**Components:**
1. **Database PITR**: 5-minute granularity (meets 1-hour RPO)
2. **Application**: Stateless (no data loss)
3. **Configuration**: Versioned in Git (no data loss)

**Actual RPO**: 5 minutes (better than 1-hour target)

## Monitoring and Alerting

### RTO Monitoring

**Metrics to Track:**
- Time to detect disaster
- Time to initiate recovery
- Time to complete recovery
- Total downtime

**Alerts:**
- Service unavailable > 5 minutes (production)
- Database failover events
- Recovery procedure initiation

### RPO Monitoring

**Metrics to Track:**
- Last backup timestamp
- Time since last backup
- Backup success rate
- PITR availability

**Alerts:**
- Backup failure
- Backup older than RPO threshold
- PITR unavailable

## Testing RTO/RPO

### Regular Testing

**Monthly:**
- Test database restore (verify RTO)
- Verify backup timestamps (verify RPO)
- Test application rollback

**Quarterly:**
- Full disaster recovery drill
- Measure actual RTO
- Verify RPO compliance

**Annually:**
- Complete disaster recovery exercise
- Review and adjust RTO/RPO if needed
- Update procedures based on learnings

### Testing Results

**Target vs Actual:**

| Environment | Target RTO | Actual RTO | Target RPO | Actual RPO |
|-------------|------------|------------|------------|------------|
| Development | 4 hours | ~2 hours | 24 hours | 24 hours |
| Staging | 2 hours | ~1 hour | 12 hours | 12 hours |
| Production | 1 hour | ~30 minutes | 1 hour | 5 minutes |

**Note**: Actual RTO/RPO are better than targets due to:
- Multi-AZ automatic failover
- PITR 5-minute granularity
- Efficient recovery procedures

## Cost vs RTO/RPO Trade-offs

### Development (Low Cost)

- **RTO**: 4 hours (acceptable)
- **RPO**: 24 hours (acceptable)
- **Cost**: Minimal (single-AZ, shorter retention)

### Staging (Balanced)

- **RTO**: 2 hours (balanced)
- **RPO**: 12 hours (balanced)
- **Cost**: Moderate (extended retention)

### Production (High Availability)

- **RTO**: 1 hour (strict)
- **RPO**: 1 hour (strict)
- **Cost**: Higher (Multi-AZ, extended retention, cross-region)

## References

- [AWS RDS Multi-AZ](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
- [AWS RDS PITR](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html)
- [Disaster Recovery Best Practices](https://aws.amazon.com/blogs/architecture/disaster-recovery-dr-architecture-on-aws-part-i-strategies-for-recovery-in-the-cloud/)
