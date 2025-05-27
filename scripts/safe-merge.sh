#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FEATURE_BRANCH=$1
TARGET_BRANCH=${2:-develop}

if [ -z "$FEATURE_BRANCH" ]; then
    echo -e "${RED}Usage: $0 <feature-branch> [target-branch]${NC}"
    echo -e "${YELLOW}Example: $0 feature/ai-agents/user-segmentation develop${NC}"
    exit 1
fi

# Determine the folder based on branch name
if [[ "$FEATURE_BRANCH" == feature/ai-agents/* ]]; then
    FOLDER="ds"
    TEAM="AI-agents"
    EMOJI="🤖"
elif [[ "$FEATURE_BRANCH" == feature/api-service/* ]]; then
    FOLDER="api"
    TEAM="API-service"
    EMOJI="🚀"
else
    echo -e "${RED}❌ Unknown branch pattern. Use feature/ai-agents/* or feature/api-service/*${NC}"
    exit 1
fi

echo -e "${BLUE}$EMOJI Selective merge: $FEATURE_BRANCH -> $TARGET_BRANCH${NC}"
echo -e "${BLUE}📁 Target folder: $FOLDER/ ($TEAM team)${NC}"
echo ""

# Check if branches exist
if ! git show-ref --verify --quiet refs/heads/$FEATURE_BRANCH; then
    if ! git show-ref --verify --quiet refs/remotes/origin/$FEATURE_BRANCH; then
        echo -e "${RED}❌ Branch $FEATURE_BRANCH does not exist locally or remotely${NC}"
        exit 1
    else
        echo -e "${YELLOW}⚠️  Checking out remote branch $FEATURE_BRANCH${NC}"
        git checkout -b $FEATURE_BRANCH origin/$FEATURE_BRANCH
    fi
fi

# Ensure we're on the latest target branch
echo -e "${BLUE}🔄 Updating $TARGET_BRANCH...${NC}"
git checkout $TARGET_BRANCH
git pull origin $TARGET_BRANCH

# Get list of files changed in the feature branch
echo -e "${BLUE}🔍 Analyzing changes...${NC}"
CHANGED_FILES=$(git diff --name-only $TARGET_BRANCH...$FEATURE_BRANCH)
echo "Files changed in feature branch:"
echo "$CHANGED_FILES"
echo ""

# Check if only the target folder is modified
INVALID_FILES=$(echo "$CHANGED_FILES" | grep -v "^$FOLDER/" | grep -v "^\.github/" | grep -v "^scripts/" || true)
if [[ -n "$INVALID_FILES" ]]; then
    echo -e "${RED}❌ Feature branch modifies files outside $FOLDER/ folder:${NC}"
    echo -e "${RED}$INVALID_FILES${NC}"
    echo ""
    echo -e "${YELLOW}Please ensure your branch only modifies files in the $FOLDER/ folder${NC}"
    exit 1
fi

# Check if there are actually changes in the target folder
TARGET_FOLDER_CHANGES=$(echo "$CHANGED_FILES" | grep "^$FOLDER/" || true)
if [[ -z "$TARGET_FOLDER_CHANGES" ]]; then
    echo -e "${YELLOW}⚠️  No changes detected in $FOLDER/ folder${NC}"
    echo -e "${YELLOW}Nothing to merge.${NC}"
    exit 0
fi

echo -e "${GREEN}✅ Validation passed - only $FOLDER/ folder will be merged${NC}"
echo "Files to be merged:"
echo "$TARGET_FOLDER_CHANGES"
echo ""

# Ask for confirmation
read -p "$(echo -e ${YELLOW}"Continue with selective merge? (y/N): "${NC}) -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Merge cancelled.${NC}"
    exit 0
fi

# Create a temporary branch for selective merge
TEMP_BRANCH="temp-merge-$(date +%s)"
echo -e "${BLUE}🔀 Creating temporary branch: $TEMP_BRANCH${NC}"
git checkout -b $TEMP_BRANCH

# Method 1: Use git checkout to selectively apply changes
echo -e "${BLUE}🔀 Applying changes from $FOLDER/ folder...${NC}"

# Get the changes from the feature branch for the specific folder
git checkout $FEATURE_BRANCH -- $FOLDER/

# Check if there are any changes to commit
if git diff --staged --quiet && git diff --quiet; then
    echo -e "${YELLOW}⚠️  No changes to commit after selective checkout${NC}"
    git checkout $TARGET_BRANCH
    git branch -D $TEMP_BRANCH
    exit 0
fi

# Stage all changes in the target folder
git add $FOLDER/

# Create a comprehensive commit message
COMMIT_MSG="Selective merge: $FEATURE_BRANCH -> $FOLDER/ only

🎯 Merged changes from $TEAM team
📁 Only $FOLDER/ folder affected
🌿 Source branch: $FEATURE_BRANCH
👥 Team: $TEAM

Files changed:
$(echo "$TARGET_FOLDER_CHANGES" | sed 's/^/  - /')"

git commit -m "$COMMIT_MSG"

# Switch back to target branch and merge
echo -e "${BLUE}🔀 Merging to $TARGET_BRANCH...${NC}"
git checkout $TARGET_BRANCH
git merge $TEMP_BRANCH --ff-only

# Clean up temporary branch
git branch -d $TEMP_BRANCH

echo ""
echo -e "${GREEN}✅ Successfully merged $FOLDER/ changes from $FEATURE_BRANCH to $TARGET_BRANCH${NC}"
echo -e "${GREEN}🚀 Ready to push: git push origin $TARGET_BRANCH${NC}"
echo ""

# Show what was merged
echo -e "${BLUE}📋 Summary of merged changes:${NC}"
git log --oneline -1
echo ""
git diff --stat HEAD~1 HEAD

# Ask if user wants to push
echo ""
read -p "$(echo -e ${YELLOW}"Push changes to origin/$TARGET_BRANCH now? (y/N): "${NC}) -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🚀 Pushing to origin/$TARGET_BRANCH...${NC}"
    git push origin $TARGET_BRANCH
    echo -e "${GREEN}✅ Successfully pushed to remote${NC}"
else
    echo -e "${YELLOW}Remember to push manually: git push origin $TARGET_BRANCH${NC}"
fi