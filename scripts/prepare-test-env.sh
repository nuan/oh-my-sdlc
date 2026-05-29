#!/usr/bin/env bash
set -e

# Load SDLC environment variables
source "$(dirname "$0")/lib/notion.sh"

PROJECT_DIR="${1:-.}"
BRANCH_NAME="${2}"

if [ -z "$BRANCH_NAME" ]; then
    echo "Usage: $0 <project-dir> <branch-name>"
    exit 1
fi

echo "--- Preparing Test Environment ---"
echo "Project Directory: $PROJECT_DIR"
echo "Target Branch: $BRANCH_NAME"

cd "$PROJECT_DIR"

# Check if branch exists, fetch it if it's remote, otherwise checkout -b
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    git checkout "$BRANCH_NAME"
else
    # Try fetching it from remote just in case
    git fetch origin "$BRANCH_NAME" 2>/dev/null || true
    if git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1; then
        git checkout "$BRANCH_NAME"
    else
        echo "Creating new branch: $BRANCH_NAME"
        git checkout -b "$BRANCH_NAME"
    fi
fi

# Ensure up-to-date if it already existed
git pull origin "$BRANCH_NAME" || true

# Simulate Test Environment Deployment (this would be replaced by actual deployment logic)
echo "Deploying to Test Environment..."
npm install
# npm run build:test || true # Example command
# npm run deploy:test || true # Example command

echo "Test Environment Preparation Complete."
