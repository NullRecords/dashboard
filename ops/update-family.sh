#!/bin/bash
# Update and redeploy family dashboards
# Run from anywhere - script finds its own location

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

echo "📍 Working directory: $REPO_DIR"
echo ""

# Determine which branch we're on
CURRENT_BRANCH=$(git branch --show-current)
echo "🌿 Current branch: $CURRENT_BRANCH"

# Pull latest changes
echo "⬇️  Pulling latest changes..."
git pull origin "$CURRENT_BRANCH"

# Change to ops directory for docker commands
cd "$SCRIPT_DIR"

echo ""
echo "🐳 Stopping existing containers..."
docker-compose -f docker-compose.family.yml down 2>/dev/null || true

echo ""
echo "🔨 Rebuilding containers (this may take a few minutes)..."
docker-compose -f docker-compose.family.yml build --no-cache

echo ""
echo "🚀 Starting containers..."
docker-compose -f docker-compose.family.yml up -d

echo ""
echo "✅ Update complete!"
echo ""
echo "📊 Container status:"
docker-compose -f docker-compose.family.yml ps

echo ""
echo "🌐 Dashboards should be available at:"
echo "   - http://parker.hoth.home"
echo "   - http://sarah.hoth.home"
echo "   - http://greg.hoth.home"
echo "   - http://ramona.hoth.home"
echo ""
echo "📝 View logs with: cd $SCRIPT_DIR && docker-compose -f docker-compose.family.yml logs -f"
