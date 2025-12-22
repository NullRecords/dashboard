#!/bin/bash
#
# Nightly Backup Script
# Commits dashboard data to the user's git branch
# Runs via cron at 2 AM

set -e

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
BRANCH="${GIT_BRANCH:-main}"
USER="${DASHBOARD_USER:-dashboard}"

echo "[$TIMESTAMP] Starting nightly backup for ${USER}..."

cd /app/data

# Check if git is configured
if [ -z "$(git config user.email 2>/dev/null)" ]; then
    echo "[$TIMESTAMP] Git not configured, skipping backup"
    exit 0
fi

# Initialize if needed
if [ ! -d ".git" ]; then
    git init
    git checkout -b "$BRANCH" 2>/dev/null || true
fi

# Switch to correct branch
git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"

# Check for changes
if git diff --quiet && git diff --staged --quiet; then
    echo "[$TIMESTAMP] No changes to commit"
    exit 0
fi

# Add and commit changes
git add -A

# Files to track
FILES_CHANGED=$(git diff --staged --name-only | wc -l)

git commit -m "🔄 Nightly backup for ${USER} - ${TIMESTAMP}

Files changed: ${FILES_CHANGED}
Automated backup from dashboard container"

echo "[$TIMESTAMP] ✅ Backup committed successfully (${FILES_CHANGED} files)"

# Push if remote is configured
if git remote -v | grep -q origin; then
    echo "[$TIMESTAMP] Pushing to origin/${BRANCH}..."
    git push origin "$BRANCH" 2>/dev/null && echo "[$TIMESTAMP] ✅ Pushed successfully" || echo "[$TIMESTAMP] ⚠️ Push failed (will retry next backup)"
fi

echo "[$TIMESTAMP] Backup complete!"
