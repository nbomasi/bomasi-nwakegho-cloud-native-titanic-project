#!/bin/bash
# Database Backup Script
# Creates manual snapshot of RDS database instance

set -euo pipefail

# Configuration
DB_INSTANCE_ID="${DB_INSTANCE_ID:-titanic-api-prod-db}"
AWS_REGION="${AWS_REGION:-eu-west-2}"
SNAPSHOT_PREFIX="${SNAPSHOT_PREFIX:-titanic-api-manual}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAPSHOT_ID="${SNAPSHOT_PREFIX}-${TIMESTAMP}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Database Backup Script ===${NC}"
echo "Database Instance: $DB_INSTANCE_ID"
echo "Region: $AWS_REGION"
echo "Snapshot ID: $SNAPSHOT_ID"
echo ""

# Check if database instance exists
echo "Checking database instance..."
if ! aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text > /dev/null 2>&1; then
  echo -e "${RED}Error: Database instance '$DB_INSTANCE_ID' not found${NC}"
  exit 1
fi

DB_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text)

if [ "$DB_STATUS" != "available" ]; then
  echo -e "${YELLOW}Warning: Database status is '$DB_STATUS', not 'available'${NC}"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Create snapshot
echo "Creating snapshot..."
SNAPSHOT_ARN=$(aws rds create-db-snapshot \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --region "$AWS_REGION" \
  --query 'DBSnapshot.DBSnapshotArn' \
  --output text)

if [ $? -eq 0 ]; then
  echo -e "${GREEN}Snapshot creation initiated: $SNAPSHOT_ID${NC}"
  echo "Snapshot ARN: $SNAPSHOT_ARN"
else
  echo -e "${RED}Error: Failed to create snapshot${NC}"
  exit 1
fi

# Monitor snapshot progress
echo ""
echo "Monitoring snapshot progress..."
echo "Press Ctrl+C to stop monitoring (snapshot will continue in background)"

while true; do
  STATUS=$(aws rds describe-db-snapshots \
    --db-snapshot-identifier "$SNAPSHOT_ID" \
    --region "$AWS_REGION" \
    --query 'DBSnapshots[0].Status' \
    --output text 2>/dev/null || echo "not-found")
  
  case "$STATUS" in
    "available")
      echo -e "${GREEN}✓ Snapshot completed successfully!${NC}"
      break
      ;;
    "creating")
      echo "Snapshot status: $STATUS (waiting...)"
      sleep 10
      ;;
    "error"|"failed")
      echo -e "${RED}✗ Snapshot failed!${NC}"
      exit 1
      ;;
    "not-found")
      echo "Waiting for snapshot to appear..."
      sleep 5
      ;;
    *)
      echo "Snapshot status: $STATUS"
      sleep 10
      ;;
  esac
done

# Get snapshot details
echo ""
echo "Snapshot Details:"
aws rds describe-db-snapshots \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --region "$AWS_REGION" \
  --query 'DBSnapshots[0].[DBSnapshotIdentifier,Status,SnapshotCreateTime,AllocatedStorage]' \
  --output table

echo ""
echo -e "${GREEN}Backup completed successfully!${NC}"
echo "Snapshot ID: $SNAPSHOT_ID"
echo "Snapshot ARN: $SNAPSHOT_ARN"
