#!/bin/bash

set -e

# Semantic Versioning Helper Script
# Generates version tags based on commit messages

LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo "Latest tag: $LATEST_TAG"

VERSION=$(echo $LATEST_TAG | sed 's/v//')
MAJOR=$(echo $VERSION | cut -d. -f1)
MINOR=$(echo $VERSION | cut -d. -f2)
PATCH=$(echo $VERSION | cut -d. -f3)

# Check commit messages since last tag
COMMITS=$(git log --oneline $LATEST_TAG..HEAD)

if echo "$COMMITS" | grep -qE "^(feat|feature)"; then
  MINOR=$((MINOR + 1))
  PATCH=0
  BUMP_TYPE="minor"
elif echo "$COMMITS" | grep -qE "^(fix|bugfix|hotfix)"; then
  PATCH=$((PATCH + 1))
  BUMP_TYPE="patch"
else
  PATCH=$((PATCH + 1))
  BUMP_TYPE="patch"
fi

NEW_VERSION="v${MAJOR}.${MINOR}.${PATCH}"
echo "New version: $NEW_VERSION (bump type: $BUMP_TYPE)"

# Create tag
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION"

# Push tag
git push origin "$NEW_VERSION"

echo "Tagged and pushed: $NEW_VERSION"
