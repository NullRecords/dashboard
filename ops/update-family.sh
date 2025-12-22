#!/bin/bash
# Update and redeploy family dashboards
# Pulls latest code and syncs all family branches
#
# Run from anywhere - script finds its own location

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Family members and their branches
FAMILY_MEMBERS=("parker" "sarah" "greg" "ramona")

cd "$REPO_DIR"

echo "📍 Working directory: $REPO_DIR"
echo ""

# Fetch all branches first
echo "🔄 Fetching all remote branches..."
git fetch --all

# Save current branch to return to it later
ORIGINAL_BRANCH=$(git branch --show-current)

# First, update master (source of truth for code)
echo ""
echo "📥 Updating master branch (main codebase)..."
git checkout master
git pull origin master
echo "   ✅ master branch updated"

echo ""
echo "🔄 Syncing family branches with master..."
echo "============================================"

# Sync each family branch with master
for member in "${FAMILY_MEMBERS[@]}"; do
    echo ""
    echo "👤 Syncing $member branch..."
    
    # Check if branch exists locally
    if git show-ref --verify --quiet "refs/heads/$member"; then
        git checkout "$member"
        # Merge master into the branch
        git merge master --no-edit -m "Sync with master" || {
            echo "   ⚠️  Merge conflict in $member, skipping sync"
            git merge --abort 2>/dev/null || true
            continue
        }
        git push origin "$member"
        echo "   ✅ $member synced with master"
    else
        # Create local branch from remote if exists
        if git show-ref --verify --quiet "refs/remotes/origin/$member"; then
            git checkout -b "$member" "origin/$member"
            git merge master --no-edit -m "Sync with master" || {
                echo "   ⚠️  Merge conflict, skipping sync"
                git merge --abort 2>/dev/null || true
                continue
            }
            git push origin "$member"
            echo "   ✅ $member created and synced"
        else
            echo "   ⚠️  $member branch doesn't exist, creating from master..."
            git checkout -b "$member" master
            git push -u origin "$member"
            echo "   ✅ $member branch created"
        fi
    fi
done

# Return to master for building
git checkout master

echo ""
echo "============================================"

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
echo "🌐 Dashboards available at:"
echo "   - http://parker.hoth.home"
echo "   - http://sarah.hoth.home"
echo "   - http://greg.hoth.home"
echo "   - http://ramona.hoth.home"
echo ""
echo "📝 View logs: docker-compose -f $SCRIPT_DIR/docker-compose.family.yml logs -f"
echo "🔁 Quick restart: docker-compose -f $SCRIPT_DIR/docker-compose.family.yml restart"
