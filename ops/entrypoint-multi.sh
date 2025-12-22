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
# Check Ollama connectivity with auto-fallback
# ============================================================================
check_ollama() {
    local host=$1
    curl -s --connect-timeout 2 "${host}/api/tags" > /dev/null 2>&1
}

if [ -n "$OLLAMA_HOST" ]; then
    echo "🤖 Checking Ollama connectivity..."
    
    OLLAMA_FOUND=false
    
    # Try the configured host first
    if check_ollama "$OLLAMA_HOST"; then
        echo "   ✅ Ollama ready at ${OLLAMA_HOST}"
        OLLAMA_FOUND=true
    else
        # Try common fallbacks for Linux Docker
        for fallback_host in "http://172.17.0.1:11434" "http://host.docker.internal:11434"; do
            if check_ollama "$fallback_host"; then
                echo "   ✅ Ollama found at ${fallback_host} (fallback)"
                export OLLAMA_HOST="$fallback_host"
                OLLAMA_FOUND=true
                break
            fi
        done
    fi
    
    if [ "$OLLAMA_FOUND" = "false" ]; then
        echo "   ⚠️  Ollama not available"
        echo "   💡 AI features will use fallback. Dashboard still works!"
        echo "   💡 Tip: Set OLLAMA_HOST to your host IP (e.g., http://192.168.68.135:11434)"
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
