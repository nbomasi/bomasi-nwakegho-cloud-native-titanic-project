#!/bin/bash

# Terraform State Lock Cleanup Script
# Use this to unlock stuck Terraform state locks

set -e

echo "🔍 Checking for Terraform state locks..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
# Update DYNAMODB_TABLE based on your environment (dev/staging/prod)
# Examples:
#   DYNAMODB_TABLE="titanicapi-terraform-state-lock-dev"
#   DYNAMODB_TABLE="titanicapi-terraform-state-lock-staging"
#   DYNAMODB_TABLE="titanicapi-terraform-state-lock-prod"
DYNAMODB_TABLE="titanicapi-terraform-state-lock-prod"
AWS_REGION="eu-west-2"

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install it first.${NC}"
    exit 1
fi

# Check for active locks in DynamoDB
echo "Checking DynamoDB table: $DYNAMODB_TABLE"
LOCK_INFO=$(aws dynamodb scan \
    --table-name $DYNAMODB_TABLE \
    --region $AWS_REGION \
    --output json 2>/dev/null || echo '{"Items":[]}')

LOCK_COUNT=$(echo $LOCK_INFO | jq '.Items | length')

if [ "$LOCK_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ No active locks found. State is clean.${NC}"
    exit 0
fi

echo -e "${YELLOW}⚠️  Found $LOCK_COUNT active lock(s):${NC}"
echo ""

# Display lock information
echo $LOCK_INFO | jq -r '.Items[] | 
    "Lock ID: \(.LockID.S // "N/A")\n" +
    "Path: \(.Info.S | fromjson | .Path // "N/A")\n" +
    "Who: \(.Info.S | fromjson | .Who // "N/A")\n" +
    "Created: \(.Info.S | fromjson | .Created // "N/A")\n" +
    "Operation: \(.Info.S | fromjson | .Operation // "N/A")\n" +
    "---"'

echo ""
echo -e "${YELLOW}⚠️  WARNING: Only unlock if you're SURE no one is running Terraform!${NC}"
echo ""

# Ask for confirmation
read -p "Do you want to force unlock? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled. No changes made."
    exit 0
fi

# Get Lock IDs and unlock them
LOCK_IDS=$(echo $LOCK_INFO | jq -r '.Items[].LockID.S')

cd "$(dirname "$0")/.."  # Go to terraform directory

for LOCK_ID in $LOCK_IDS; do
    echo ""
    echo "🔓 Unlocking: $LOCK_ID"
    
    # Try to unlock
    if echo "yes" | terraform force-unlock "$LOCK_ID" 2>/dev/null; then
        echo -e "${GREEN}✅ Successfully unlocked: $LOCK_ID${NC}"
    else
        echo -e "${RED}❌ Failed to unlock: $LOCK_ID${NC}"
        echo "You may need to run: terraform force-unlock $LOCK_ID"
    fi
done

echo ""
echo -e "${GREEN}✅ Lock cleanup complete!${NC}"
echo ""
echo "You can now run your terraform commands."

