#!/bin/bash
# Database Restore Script
# Restores RDS database from snapshot

set -euo pipefail

# Configuration
SOURCE_SNAPSHOT_ID="${1:-}"
TARGET_DB_ID="${TARGET_DB_ID:-titanic-api-prod-db-restored}"
AWS_REGION="${AWS_REGION:-eu-west-2}"
DB_INSTANCE_CLASS="${DB_INSTANCE_CLASS:-db.t3.medium}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Database Restore Script ===${NC}"

# Check if snapshot ID provided
if [ -z "$SOURCE_SNAPSHOT_ID" ]; then
  echo -e "${RED}Error: Snapshot ID required${NC}"
  echo "Usage: $0 <snapshot-id>"
  echo ""
  echo "Available snapshots:"
  aws rds describe-db-snapshots \
    --region "$AWS_REGION" \
    --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime,Status]' \
    --output table | head -20
  exit 1
fi

echo "Source Snapshot: $SOURCE_SNAPSHOT_ID"
echo "Target DB Instance: $TARGET_DB_ID"
echo "Region: $AWS_REGION"
echo "Instance Class: $DB_INSTANCE_CLASS"
echo ""

# Verify snapshot exists
echo "Verifying snapshot..."
SNAPSHOT_STATUS=$(aws rds describe-db-snapshots \
  --db-snapshot-identifier "$SOURCE_SNAPSHOT_ID" \
  --region "$AWS_REGION" \
  --query 'DBSnapshots[0].Status' \
  --output text 2>/dev/null || echo "not-found")

if [ "$SNAPSHOT_STATUS" != "available" ]; then
  if [ "$SNAPSHOT_STATUS" == "not-found" ]; then
    echo -e "${RED}Error: Snapshot '$SOURCE_SNAPSHOT_ID' not found${NC}"
  else
    echo -e "${RED}Error: Snapshot status is '$SNAPSHOT_STATUS', not 'available'${NC}"
  fi
  exit 1
fi

echo -e "${GREEN}✓ Snapshot verified${NC}"

# Check if target instance already exists
if aws rds describe-db-instances \
  --db-instance-identifier "$TARGET_DB_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text > /dev/null 2>&1; then
  echo -e "${YELLOW}Warning: Target instance '$TARGET_DB_ID' already exists${NC}"
  read -p "Delete and recreate? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting existing instance..."
    aws rds delete-db-instance \
      --db-instance-identifier "$TARGET_DB_ID" \
      --skip-final-snapshot \
      --region "$AWS_REGION" > /dev/null
    
    echo "Waiting for deletion..."
    aws rds wait db-instance-deleted \
      --db-instance-identifier "$TARGET_DB_ID" \
      --region "$AWS_REGION"
    echo -e "${GREEN}✓ Instance deleted${NC}"
  else
    echo "Exiting..."
    exit 1
  fi
fi

# Restore from snapshot
echo ""
echo "Restoring database from snapshot..."
RESTORE_OUTPUT=$(aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier "$TARGET_DB_ID" \
  --db-snapshot-identifier "$SOURCE_SNAPSHOT_ID" \
  --db-instance-class "$DB_INSTANCE_CLASS" \
  --publicly-accessible false \
  --region "$AWS_REGION" \
  --output json)

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ Restore initiated${NC}"
  DB_ENDPOINT=$(echo "$RESTORE_OUTPUT" | jq -r '.DBInstance.Endpoint.Address')
  echo "Target endpoint: $DB_ENDPOINT"
else
  echo -e "${RED}Error: Failed to initiate restore${NC}"
  exit 1
fi

# Monitor restore progress
echo ""
echo "Monitoring restore progress..."
echo "Press Ctrl+C to stop monitoring (restore will continue in background)"

while true; do
  STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$TARGET_DB_ID" \
    --region "$AWS_REGION" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")
  
  case "$STATUS" in
    "available")
      echo -e "${GREEN}✓ Restore completed successfully!${NC}"
      break
      ;;
    "creating"|"backing-up"|"modifying")
      echo "Restore status: $STATUS (waiting...)"
      sleep 15
      ;;
    "failed"|"error")
      echo -e "${RED}✗ Restore failed!${NC}"
      exit 1
      ;;
    "not-found")
      echo "Waiting for instance to appear..."
      sleep 5
      ;;
    *)
      echo "Restore status: $STATUS"
      sleep 15
      ;;
  esac
done

# Get instance details
echo ""
echo "Restored Instance Details:"
aws rds describe-db-instances \
  --db-instance-identifier "$TARGET_DB_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address,DBInstanceClass]' \
  --output table

echo ""
echo -e "${GREEN}Restore completed successfully!${NC}"
echo "Target DB Instance: $TARGET_DB_ID"
echo "Endpoint: $DB_ENDPOINT"
echo ""
echo "Next steps:"
echo "1. Update Secrets Manager with new endpoint"
echo "2. Restart application pods"
echo "3. Verify application functionality"
