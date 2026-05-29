#!/usr/bin/env bash
set -e

# Load SDLC environment variables
source "$(dirname "$0")/lib/notion.sh"

PROJECT_DIR="${1:-.}"
SPRINT_OR_BRANCH="${2}"

if [ -z "$SPRINT_OR_BRANCH" ]; then
    echo "Usage: $0 <project-dir> <branch-name-or-sprint-id>"
    exit 1
fi

BRANCH_NAME="$SPRINT_OR_BRANCH"

if [[ "$SPRINT_OR_BRANCH" =~ ^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$ ]]; then
    # Load config to ensure variables are set if needed (mostly NOTION_TOKEN is already in env)
    sprint_page=$(notion_get_page "$SPRINT_OR_BRANCH" 2>/dev/null || true)
    if [ -n "$sprint_page" ] && echo "$sprint_page" | jq -e '.object == "page"' >/dev/null 2>&1; then
        sprint_branch=$(echo "$sprint_page" | jq -r '.properties["分支"].rich_text[0].plain_text // empty')
        if [ -n "$sprint_branch" ]; then
            BRANCH_NAME="$sprint_branch"
            echo "Resolved Sprint ID '$SPRINT_OR_BRANCH' to branch '$BRANCH_NAME' via Notion property"
        fi
    fi
fi

if [ "$BRANCH_NAME" = "$SPRINT_OR_BRANCH" ]; then
    CONFIG_FILE="$PROJECT_DIR/.sdlc/config.json"
    if [ -f "$CONFIG_FILE" ]; then
        MAPPED_BRANCH=$(jq -r --arg key "$SPRINT_OR_BRANCH" '.sprint_branches[$key] // empty' "$CONFIG_FILE")
        if [ -n "$MAPPED_BRANCH" ]; then
            BRANCH_NAME="$MAPPED_BRANCH"
            echo "Resolved Sprint ID '$SPRINT_OR_BRANCH' to branch '$BRANCH_NAME' via config"
        fi
    fi
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
