#!/bin/bash
# Multi-Persona Dashboard Deployment Script
# Deploys 5 separate dashboard instances on hoth

set -e

echo "🚀 Multi-Persona Dashboard Deployment"
echo "======================================"

# Configuration
DEPLOY_ROOT="/home/glind/dashboards"
REPO_URL="https://github.com/glindberg2000/dashboard.git"
BRANCHES=("master" "parker" "ramona" "sarah" "greg")
BASE_PORT=8020

# Subdomain mappings (for reference)
declare -A SUBDOMAINS=(
    ["master"]="roger.hoth.home"
    ["parker"]="parker.hoth.home"
    ["ramona"]="ramona.hoth.home"
    ["sarah"]="sarah.hoth.home"
    ["greg"]="greg.hoth.home"
)

# Stop all running dashboards
echo ""
echo "🛑 Stopping all running dashboard instances..."
pkill -f "uvicorn.*src.main:app" 2>/dev/null || true
sleep 2

# Clean up old deployment
if [ -d "$DEPLOY_ROOT" ]; then
    echo "🧹 Removing old deployment directory..."
    rm -rf "$DEPLOY_ROOT"
fi

# Create deployment root
echo "📁 Creating deployment directory structure..."
mkdir -p "$DEPLOY_ROOT"

# Clone and setup each branch
for i in "${!BRANCHES[@]}"; do
    BRANCH="${BRANCHES[$i]}"
    PORT=$((BASE_PORT + i))
    DIR="$DEPLOY_ROOT/$BRANCH"
    
    echo ""
    echo "📦 Setting up $BRANCH (port $PORT)..."
    echo "   Directory: $DIR"
    echo "   URL: ${SUBDOMAINS[$BRANCH]}"
    
    # Clone the repo
    echo "   ⬇️  Cloning repository..."
    git clone -b "$BRANCH" "$REPO_URL" "$DIR" 2>&1 | grep -v "Cloning\|remote:" || true
    
    # Setup Python virtual environment
    echo "   🐍 Creating virtual environment..."
    cd "$DIR"
    python3 -m venv .venv
    source .venv/bin/activate
    
    # Install dependencies quietly
    echo "   📚 Installing dependencies..."
    pip install --quiet --upgrade pip
    pip install --quiet -r requirements.txt
    
    deactivate
    
    # Create startup script for this instance
    cat > "$DIR/start.sh" << EOF
#!/bin/bash
cd "$DIR"
source .venv/bin/activate
export DASHBOARD_PORT=$PORT
uvicorn src.main:app --host 0.0.0.0 --port $PORT --reload > "$DIR/dashboard.log" 2>&1 &
echo \$! > "$DIR/dashboard.pid"
echo "✅ $BRANCH dashboard started on port $PORT"
echo "   URL: http://hoth.home:$PORT"
echo "   Subdomain: ${SUBDOMAINS[$BRANCH]}"
echo "   Log: $DIR/dashboard.log"
echo "   PID: \$(cat $DIR/dashboard.pid)"
EOF
    chmod +x "$DIR/start.sh"
    
    # Create stop script
    cat > "$DIR/stop.sh" << EOF
#!/bin/bash
if [ -f "$DIR/dashboard.pid" ]; then
    PID=\$(cat "$DIR/dashboard.pid")
    kill \$PID 2>/dev/null || true
    rm "$DIR/dashboard.pid"
    echo "✅ $BRANCH dashboard stopped"
else
    echo "⚠️  No PID file found for $BRANCH"
fi
EOF
    chmod +x "$DIR/stop.sh"
    
    echo "   ✅ Setup complete!"
done

# Create master control scripts
cat > "$DEPLOY_ROOT/start-all.sh" << 'EOF'
#!/bin/bash
echo "🚀 Starting all dashboards..."
for dir in master parker ramona sarah greg; do
    if [ -d "/home/glind/dashboards/$dir" ]; then
        /home/glind/dashboards/$dir/start.sh
    fi
done
echo ""
echo "✅ All dashboards started!"
echo ""
echo "Access URLs:"
echo "  Master (Roger): http://hoth.home:8020 or http://roger.hoth.home"
echo "  Parker:         http://hoth.home:8021 or http://parker.hoth.home"
echo "  Ramona:         http://hoth.home:8022 or http://ramona.hoth.home"
echo "  Sarah:          http://hoth.home:8023 or http://sarah.hoth.home"
echo "  Greg:           http://hoth.home:8024 or http://greg.hoth.home"
EOF
chmod +x "$DEPLOY_ROOT/start-all.sh"

cat > "$DEPLOY_ROOT/stop-all.sh" << 'EOF'
#!/bin/bash
echo "🛑 Stopping all dashboards..."
for dir in master parker ramona sarah greg; do
    if [ -d "/home/glind/dashboards/$dir" ]; then
        /home/glind/dashboards/$dir/stop.sh
    fi
done
pkill -f "uvicorn.*src.main:app" 2>/dev/null || true
echo "✅ All dashboards stopped!"
EOF
chmod +x "$DEPLOY_ROOT/stop-all.sh"

cat > "$DEPLOY_ROOT/status.sh" << 'EOF'
#!/bin/bash
echo "📊 Dashboard Status"
echo "==================="
echo ""
for dir in master parker ramona sarah greg; do
    if [ -f "/home/glind/dashboards/$dir/dashboard.pid" ]; then
        PID=$(cat "/home/glind/dashboards/$dir/dashboard.pid")
        if ps -p $PID > /dev/null 2>&1; then
            PORT=$((8020 + $(echo "master parker ramona sarah greg" | tr ' ' '\n' | grep -n "^$dir$" | cut -d: -f1) - 1))
            echo "✅ $dir: Running (PID: $PID, Port: $PORT)"
        else
            echo "❌ $dir: Stopped (stale PID file)"
        fi
    else
        echo "⭕ $dir: Not running"
    fi
done
EOF
chmod +x "$DEPLOY_ROOT/status.sh"

# Create update script for pulling latest changes
cat > "$DEPLOY_ROOT/update-all.sh" << 'EOF'
#!/bin/bash
echo "🔄 Updating all dashboards..."
/home/glind/dashboards/stop-all.sh
sleep 2

for dir in master parker ramona sarah greg; do
    if [ -d "/home/glind/dashboards/$dir" ]; then
        echo "📥 Updating $dir..."
        cd "/home/glind/dashboards/$dir"
        git pull
        source .venv/bin/activate
        pip install --quiet -r requirements.txt
        deactivate
    fi
done

/home/glind/dashboards/start-all.sh
EOF
chmod +x "$DEPLOY_ROOT/update-all.sh"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📝 Management Commands:"
echo "   Start all:   $DEPLOY_ROOT/start-all.sh"
echo "   Stop all:    $DEPLOY_ROOT/stop-all.sh"
echo "   Status:      $DEPLOY_ROOT/status.sh"
echo "   Update all:  $DEPLOY_ROOT/update-all.sh"
echo ""
echo "Starting all dashboards now..."
"$DEPLOY_ROOT/start-all.sh"
