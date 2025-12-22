#!/bin/bash
#
# Multi-User Dashboard Entrypoint
# Configures git, starts cron, waits for Ollama, and launches the dashboard

set -e

echo "🚀 Starting ${DASHBOARD_USER:-dashboard}'s Dashboard..."
echo "   Port: ${DASHBOARD_PORT:-8020}"
echo "   Hostname: ${DASHBOARD_HOSTNAME:-localhost}"

# ============================================================================
# Configure Git for nightly backups
# ============================================================================
if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then
    echo "📝 Configuring git..."
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    git config --global --add safe.directory /app
fi

# ============================================================================
# Initialize git repo if needed (for tracking data changes)
# ============================================================================
if [ "$ENABLE_NIGHTLY_BACKUP" = "true" ]; then
    echo "📦 Enabling nightly git backups to branch: ${GIT_BRANCH:-main}"
    
    # Initialize data directory as git repo if not already
    if [ ! -d "/app/data/.git" ]; then
        cd /app/data
        git init
        git checkout -b "${GIT_BRANCH:-main}" 2>/dev/null || git checkout "${GIT_BRANCH:-main}" 2>/dev/null || true
    fi
fi

# ============================================================================
# Start cron daemon for scheduled tasks
# ============================================================================
echo "⏰ Starting cron daemon..."
service cron start || cron

# ============================================================================
# Wait for Ollama (if configured)
# ============================================================================
if [ -n "$OLLAMA_HOST" ]; then
    echo "🤖 Waiting for Ollama at ${OLLAMA_HOST}..."
    
    MAX_RETRIES=30
    RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -s "${OLLAMA_HOST}/api/tags" > /dev/null 2>&1; then
            echo "   ✅ Ollama is ready!"
            break
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "   ⏳ Waiting... (${RETRY_COUNT}/${MAX_RETRIES})"
        sleep 2
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "   ⚠️  Ollama not available, continuing anyway..."
    fi
fi

# ============================================================================
# Set database path
# ============================================================================
export DATABASE_PATH="${DATABASE_PATH:-/app/data/dashboard.db}"
echo "💾 Database: ${DATABASE_PATH}"

# ============================================================================
# Start the dashboard
# ============================================================================
echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  🏠 ${DASHBOARD_USER:-Dashboard}'s Dashboard Starting         ║"
echo "║  📍 http://${DASHBOARD_HOSTNAME:-localhost}:${DASHBOARD_PORT:-8020}          ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

exec uvicorn src.main:app \
    --host 0.0.0.0 \
    --port "${DASHBOARD_PORT:-8020}" \
    --workers 1
