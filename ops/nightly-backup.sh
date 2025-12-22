#!/bin/bash
# Nightly backup script for Personal Dashboard
# Commits data changes to git and optionally pushes to remote

set -e

LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')] BACKUP:"
APP_DIR="/app"
DATA_DIR="/app/data"
BRANCH="${GIT_BRANCH:-${DASHBOARD_USER:-main}}"

log() {
    echo "${LOG_PREFIX} $1"
}

log "=========================================="
log "Starting nightly backup for user: ${DASHBOARD_USER:-unknown}"
log "=========================================="

# Check if git is configured
if [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then
    log "ERROR: Git not configured. Set GIT_USER_NAME and GIT_USER_EMAIL"
    exit 1
fi

cd "$APP_DIR"

# Ensure we're in a git repo
if [ ! -d ".git" ]; then
    log "ERROR: Not a git repository"
    exit 1
fi

# Check for changes
if git diff --quiet && git diff --cached --quiet; then
    log "No changes to commit"
    exit 0
fi

# Create backup of database before commit
if [ -f "$DATA_DIR/dashboard.db" ]; then
    BACKUP_FILE="$DATA_DIR/backups/dashboard_$(date +%Y%m%d_%H%M%S).db"
    mkdir -p "$DATA_DIR/backups"
    cp "$DATA_DIR/dashboard.db" "$BACKUP_FILE"
    log "Database backed up to: $BACKUP_FILE"
    
    # Keep only last 7 backups
    ls -t "$DATA_DIR/backups/"*.db 2>/dev/null | tail -n +8 | xargs -r rm
    log "Cleaned old backups (keeping last 7)"
fi

# Stage all data changes
log "Staging changes..."
git add data/*.json data/*.db data/skins/ data/personality_profiles/ 2>/dev/null || true
git add tokens/ 2>/dev/null || true

# Check if there are staged changes
if git diff --cached --quiet; then
    log "No data changes to commit"
    exit 0
fi

# Create commit with timestamp
COMMIT_MSG="[Auto] Nightly backup for ${DASHBOARD_USER:-unknown} - $(date '+%Y-%m-%d %H:%M')"
log "Creating commit: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"

# Push to remote if configured
if [ -n "$GIT_TOKEN" ] && [ "$GIT_AUTO_PUSH" = "true" ]; then
    log "Pushing to remote branch: $BRANCH"
    
    # Ensure we're on the right branch
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
        log "Switching to branch: $BRANCH"
        git checkout -B "$BRANCH"
    fi
    
    # Push changes
    if git push origin "$BRANCH" 2>&1; then
        log "Successfully pushed to origin/$BRANCH"
    else
        log "WARNING: Push failed - changes committed locally only"
    fi
else
    log "Auto-push disabled (set GIT_AUTO_PUSH=true and GIT_TOKEN to enable)"
fi

log "Backup complete!"
log "=========================================="
