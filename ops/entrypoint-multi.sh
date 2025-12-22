#!/bin/bash
# Docker entrypoint script for Multi-user Personal Dashboard
# Handles git sync, cron startup, and application launch

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        🚀 Personal Dashboard - Starting Up                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "  User: ${DASHBOARD_USER:-default}"
echo "  Port: ${DASHBOARD_PORT:-8020}"
echo "  Host: ${DASHBOARD_HOSTNAME:-localhost}"
echo ""

# ============================================================================
# Git Configuration
# ============================================================================
configure_git() {
    if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then
        echo "⚙️  Configuring git..."
        git config --global user.name "$GIT_USER_NAME"
        git config --global user.email "$GIT_USER_EMAIL"
        git config --global --add safe.directory /app
        
        # Store credentials if provided
        if [ -n "$GIT_TOKEN" ]; then
            git config --global credential.helper store
            # Create credential file for GitHub
            if [ -n "$GIT_REPO_URL" ]; then
                REPO_HOST=$(echo "$GIT_REPO_URL" | sed -n 's|https://\([^/]*\)/.*|\1|p')
                echo "https://${GIT_USER_NAME}:${GIT_TOKEN}@${REPO_HOST}" > ~/.git-credentials
                chmod 600 ~/.git-credentials
            fi
        fi
        echo "✅ Git configured for ${GIT_USER_NAME}"
    else
        echo "⚠️  Git user not configured (GIT_USER_NAME/GIT_USER_EMAIL not set)"
    fi
}

# ============================================================================
# Initialize Data Directory
# ============================================================================
initialize_data() {
    echo "📁 Initializing data directories..."
    
    # Ensure directories exist with proper permissions
    mkdir -p /app/data/voice_cache
    mkdir -p /app/data/skins
    mkdir -p /app/data/personality_profiles
    mkdir -p /app/tokens
    mkdir -p /app/logs
    
    # Copy default skins if not present
    if [ ! -d "/app/data/skins/roger" ] && [ -d "/app/data/skins.default/roger" ]; then
        cp -r /app/data/skins.default/* /app/data/skins/
        echo "✅ Copied default skin configurations"
    fi
    
    # Initialize database if not exists
    if [ ! -f "/app/data/dashboard.db" ]; then
        echo "📊 Database will be initialized on first run"
    else
        echo "✅ Database found: /app/data/dashboard.db"
        # Show database stats
        if command -v sqlite3 &> /dev/null; then
            TABLES=$(sqlite3 /app/data/dashboard.db "SELECT count(*) FROM sqlite_master WHERE type='table'")
            echo "   Tables: ${TABLES}"
        fi
    fi
}

# ============================================================================
# Wait for Dependencies
# ============================================================================
wait_for_ollama() {
    OLLAMA_URL="${OLLAMA_HOST:-http://localhost:11434}"
    
    # Skip if Ollama is disabled
    if [ "$OLLAMA_DISABLED" = "true" ]; then
        echo "⚠️  Ollama disabled, skipping wait"
        return 0
    fi
    
    echo "⏳ Checking Ollama at ${OLLAMA_URL}..."
    
    max_attempts=30
    attempt=0
    
    while ! curl -s "${OLLAMA_URL}/api/tags" > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            echo "⚠️  Ollama not available at ${OLLAMA_URL} - continuing without it"
            echo "   AI features may be limited"
            return 0
        fi
        echo "   Waiting for Ollama... ($attempt/$max_attempts)"
        sleep 2
    done
    
    echo "✅ Ollama is ready at ${OLLAMA_URL}"
    
    # List available models
    MODELS=$(curl -s "${OLLAMA_URL}/api/tags" | python3 -c "import sys,json; d=json.load(sys.stdin); print(', '.join([m['name'] for m in d.get('models',[])]))" 2>/dev/null || echo "unknown")
    echo "   Models: ${MODELS}"
}

# ============================================================================
# Start Cron for Nightly Backups
# ============================================================================
start_cron() {
    if [ "$ENABLE_NIGHTLY_BACKUP" = "true" ]; then
        echo "⏰ Starting cron for nightly backups..."
        service cron start || cron
        echo "✅ Cron started (backups at 2 AM)"
    else
        echo "⚠️  Nightly backups disabled (set ENABLE_NIGHTLY_BACKUP=true to enable)"
    fi
}

# ============================================================================
# Main Startup
# ============================================================================

# Configure git for nightly commits
configure_git

# Initialize data directories
initialize_data

# Wait for Ollama (if applicable)
wait_for_ollama

# Start cron daemon for nightly backups
start_cron

# Display startup info
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Dashboard Ready                             ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║  🎙️  Voice: Piper TTS (ryan-high + lessac-medium)              ║"
echo "║  🧠 AI: Ollama at ${OLLAMA_HOST:-http://localhost:11434}       "
echo "║  📊 URL: http://0.0.0.0:${DASHBOARD_PORT:-8020}                "
echo "║  👤 User: ${DASHBOARD_USER:-default}                           "
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Start the application
exec python -m uvicorn src.main:app --host 0.0.0.0 --port ${DASHBOARD_PORT:-8020}
