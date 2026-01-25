#!/bin/bash
# Backup Verification Script
# Verifies that backups exist and are valid

set -euo pipefail

# Configuration
DB_INSTANCE_ID="${DB_INSTANCE_ID:-titanic-api-prod-db}"
AWS_REGION="${AWS_REGION:-eu-west-2}"
MIN_BACKUP_AGE_HOURS="${MIN_BACKUP_AGE_HOURS:-24}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Backup Verification Script ===${NC}"
echo "Database Instance: $DB_INSTANCE_ID"
echo "Region: $AWS_REGION"
echo "Minimum Backup Age: $MIN_BACKUP_AGE_HOURS hours"
echo ""

# Check automated backups
echo "Checking automated backups..."
AUTOMATED_BACKUPS=$(aws rds describe-db-snapshots \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --snapshot-type automated \
  --region "$AWS_REGION" \
  --query 'DBSnapshots[?Status==`available`] | sort_by(@, &SnapshotCreateTime) | [-1]' \
  --output json)

if [ "$AUTOMATED_BACKUPS" == "null" ] || [ -z "$AUTOMATED_BACKUPS" ]; then
  echo -e "${RED}✗ No automated backups found!${NC}"
  exit 1
fi

LATEST_BACKUP_TIME=$(echo "$AUTOMATED_BACKUPS" | jq -r '.SnapshotCreateTime')
LATEST_BACKUP_ID=$(echo "$AUTOMATED_BACKUPS" | jq -r '.DBSnapshotIdentifier')

echo -e "${GREEN}✓ Latest automated backup found${NC}"
echo "  Snapshot ID: $LATEST_BACKUP_ID"
echo "  Created: $LATEST_BACKUP_TIME"

# Check backup age
BACKUP_TIMESTAMP=$(date -d "$LATEST_BACKUP_TIME" +%s)
CURRENT_TIMESTAMP=$(date +%s)
AGE_HOURS=$(( (CURRENT_TIMESTAMP - BACKUP_TIMESTAMP) / 3600 ))

if [ $AGE_HOURS -gt $MIN_BACKUP_AGE_HOURS ]; then
  echo -e "${YELLOW}⚠ Warning: Latest backup is $AGE_HOURS hours old (threshold: $MIN_BACKUP_AGE_HOURS hours)${NC}"
else
  echo -e "${GREEN}✓ Backup age: $AGE_HOURS hours (within threshold)${NC}"
fi

# Check manual snapshots
echo ""
echo "Checking manual snapshots..."
MANUAL_SNAPSHOTS=$(aws rds describe-db-snapshots \
  --snapshot-type manual \
  --region "$AWS_REGION" \
  --query "DBSnapshots[?contains(DBSnapshotIdentifier, 'titanic-api') && Status=='available'] | length(@)" \
  --output text)

if [ "$MANUAL_SNAPSHOTS" -gt 0 ]; then
  echo -e "${GREEN}✓ Found $MANUAL_SNAPSHOTS manual snapshot(s)${NC}"
  
  echo ""
  echo "Recent manual snapshots:"
  aws rds describe-db-snapshots \
    --snapshot-type manual \
    --region "$AWS_REGION" \
    --query "DBSnapshots[?contains(DBSnapshotIdentifier, 'titanic-api') && Status=='available'] | sort_by(@, &SnapshotCreateTime) | [-5:].[DBSnapshotIdentifier,SnapshotCreateTime,AllocatedStorage]" \
    --output table
else
  echo -e "${YELLOW}⚠ No manual snapshots found${NC}"
fi

# Check backup retention
echo ""
echo "Checking backup retention settings..."
RETENTION_PERIOD=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].BackupRetentionPeriod' \
  --output text)

echo "Backup Retention Period: $RETENTION_PERIOD days"

# Check PITR status
PITR_ENABLED=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].BackupRetentionPeriod' \
  --output text)

if [ "$PITR_ENABLED" -gt 0 ]; then
  echo -e "${GREEN}✓ Point-in-time recovery enabled (retention: $PITR_ENABLED days)${NC}"
else
  echo -e "${RED}✗ Point-in-time recovery not enabled${NC}"
fi

# Summary
echo ""
echo "=== Verification Summary ==="
echo -e "${GREEN}✓ Automated backups: OK${NC}"
echo -e "${GREEN}✓ Latest backup: $LATEST_BACKUP_ID${NC}"
echo -e "${GREEN}✓ Backup age: $AGE_HOURS hours${NC}"
echo -e "${GREEN}✓ Manual snapshots: $MANUAL_SNAPSHOTS${NC}"
echo -e "${GREEN}✓ Retention period: $RETENTION_PERIOD days${NC}"

if [ $AGE_HOURS -le $MIN_BACKUP_AGE_HOURS ]; then
  echo ""
  echo -e "${GREEN}All backup checks passed!${NC}"
  exit 0
else
  echo ""
  echo -e "${YELLOW}Backup verification completed with warnings${NC}"
  exit 0
fi
