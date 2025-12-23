#!/bin/bash
#
# Deploy Family Dashboards
# Builds and runs all family member dashboards with Traefik reverse proxy
#
# WORKFLOW (Source code is mounted as volumes!):
#   - Code changes: Use 'update' to pull and restart (no rebuild needed)
#   - Dependency changes: Use 'build' to rebuild images
#   - First time setup: Use 'build' then 'start'
#
# Usage:
#   ./deploy-family.sh start     # Start containers (no rebuild)
#   ./deploy-family.sh build     # Build/rebuild images
#   ./deploy-family.sh update    # Pull code and restart containers
#   ./deploy-family.sh stop      # Stop all containers
#   ./deploy-family.sh restart   # Restart all containers
#   ./deploy-family.sh logs      # View logs
#   ./deploy-family.sh status    # Check status

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       🏠 Family Dashboard Deployment                  ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_env() {
    if [ ! -f ".env" ]; then
        if [ -f ".env.family.example" ]; then
            echo -e "${YELLOW}⚠️  No .env file found. Creating from example...${NC}"
            cp .env.family.example .env
            echo -e "${YELLOW}   Please edit ops/.env with your API keys!${NC}"
        fi
    fi
}

status() {
    print_header
    echo -e "${GREEN}📊 Dashboard Status:${NC}"
    echo ""
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "dashboard-|traefik|NAMES"
    echo ""
    echo -e "${GREEN}🌐 Access URLs:${NC}"
    echo "   • http://parker.hoth.home"
    echo "   • http://sarah.hoth.home"
    echo "   • http://greg.hoth.home"
    echo "   • http://ramona.hoth.home"
    echo "   • http://localhost:8080 (Traefik Dashboard)"
    echo ""
}

start() {
    print_header
    check_env
    
    echo -e "${GREEN}� Starting all dashboards...${NC}"
    echo -e "${CYAN}   (Using existing images - run 'build' first if needed)${NC}"
    echo ""
    
    docker-compose -f docker-compose.family.yml up -d
    
    echo ""
    echo -e "${GREEN}✅ All dashboards started!${NC}"
    echo ""
    status
}

build() {
    print_header
    check_env
    
    echo -e "${GREEN}🔨 Building dashboard images...${NC}"
    echo -e "${CYAN}   (Only needed when dependencies change)${NC}"
    echo ""
    
    # Enable BuildKit for better caching
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    
    docker-compose -f docker-compose.family.yml build
    
    echo ""
    echo -e "${GREEN}✅ Images built successfully!${NC}"
    echo -e "${CYAN}   Run './deploy-family.sh start' to start containers${NC}"
    echo ""
}

build_start() {
    print_header
    check_env
    
    echo -e "${GREEN}🔨 Building and starting all dashboards...${NC}"
    echo ""
    
    # Enable BuildKit for better caching
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    
    docker-compose -f docker-compose.family.yml up -d --build
    
    echo ""
    echo -e "${GREEN}✅ All dashboards built and started!${NC}"
    echo ""
    status
}

update() {
    print_header
    
    echo -e "${GREEN}📥 Pulling latest code changes...${NC}"
    cd "$SCRIPT_DIR/.."
    git pull
    cd "$SCRIPT_DIR"
    
    echo ""
    echo -e "${GREEN}🔄 Restarting containers to pick up changes...${NC}"
    docker-compose -f docker-compose.family.yml restart
    
    echo ""
    echo -e "${GREEN}✅ Code updated and containers restarted!${NC}"
    echo -e "${CYAN}   (No rebuild needed - code is mounted as volumes)${NC}"
    echo ""
    status
}

update_user() {
    local user=$1
    print_header
    
    echo -e "${GREEN}📥 Pulling latest code changes...${NC}"
    cd "$SCRIPT_DIR/.."
    git pull
    cd "$SCRIPT_DIR"
    
    echo ""
    echo -e "${GREEN}🔄 Restarting $user's container...${NC}"
    docker-compose -f docker-compose.family.yml restart "dashboard-$user"
    
    echo ""
    echo -e "${GREEN}✅ $user's dashboard updated!${NC}"
}

stop() {
    print_header
    echo -e "${YELLOW}🛑 Stopping all dashboards...${NC}"
    docker-compose -f docker-compose.family.yml down
    echo -e "${GREEN}✅ All dashboards stopped.${NC}"
}

restart() {
    print_header
    echo -e "${YELLOW}🔄 Restarting all dashboards...${NC}"
    docker-compose -f docker-compose.family.yml restart
    echo -e "${GREEN}✅ All dashboards restarted.${NC}"
    status
}

logs() {
    echo -e "${GREEN}📜 Showing logs (Ctrl+C to exit)...${NC}"
    docker-compose -f docker-compose.family.yml logs -f
}

logs_user() {
    local user=$1
    echo -e "${GREEN}📜 Showing logs for $user (Ctrl+C to exit)...${NC}"
    docker logs -f "dashboard-$user"
}

rebuild_user() {
    local user=$1
    echo -e "${GREEN}🔨 Rebuilding $user's dashboard...${NC}"
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    docker-compose -f docker-compose.family.yml up -d --build "dashboard-$user"
    echo -e "${GREEN}✅ $user's dashboard rebuilt and restarted.${NC}"
}

build_user() {
    local user=$1
    echo -e "${GREEN}🔨 Building $user's dashboard image...${NC}"
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    docker-compose -f docker-compose.family.yml build "dashboard-$user"
    echo -e "${GREEN}✅ $user's image built. Run 'start' to use it.${NC}"
}

setup_dns() {
    print_header
    echo -e "${GREEN}🌐 DNS Setup Instructions${NC}"
    echo ""
    echo "Add these entries to your local DNS (router, Pi-hole, or /etc/hosts):"
    echo ""
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo "   $SERVER_IP   parker.hoth.home"
    echo "   $SERVER_IP   sarah.hoth.home"
    echo "   $SERVER_IP   greg.hoth.home"
    echo "   $SERVER_IP   ramona.hoth.home"
    echo ""
    echo "For testing on this machine, add to /etc/hosts:"
    echo "   sudo nano /etc/hosts"
    echo ""
}

case "${1:-start}" in
    start|up)
        start
        ;;
    build)
        if [ -n "$2" ]; then
            build_user "$2"
        else
            build
        fi
        ;;
    build-start)
        build_start
        ;;
    stop|down)
        stop
        ;;
    restart)
        restart
        ;;
    update)
        if [ -n "$2" ]; then
            update_user "$2"
        else
            update
        fi
        ;;
    logs)
        if [ -n "$2" ]; then
            logs_user "$2"
        else
            logs
        fi
        ;;
    status|ps)
        status
        ;;
    rebuild)
        if [ -n "$2" ]; then
            rebuild_user "$2"
        else
            echo "Usage: $0 rebuild <username>"
            echo "Example: $0 rebuild parker"
        fi
        ;;
    dns|setup-dns)
        setup_dns
        ;;
    *)
        echo "Usage: $0 {start|build|update|stop|restart|logs|status|dns}"
        echo ""
        echo -e "${GREEN}WORKFLOW:${NC}"
        echo "  Source code is mounted as volumes - no rebuild needed for code changes!"
        echo "  • First time: build → start"
        echo "  • Code changes: update (or just restart)"
        echo "  • Dependency changes: build → restart"
        echo ""
        echo -e "${GREEN}Commands:${NC}"
        echo "  start           Start containers (no rebuild)"
        echo "  build [user]    Build images (only for dependency changes)"
        echo "  build-start     Build and start in one step"
        echo "  update [user]   Git pull + restart containers"
        echo "  stop            Stop all containers"
        echo "  restart         Restart all containers"
        echo "  logs [user]     View logs (optionally for specific user)"
        echo "  status          Show dashboard status"
        echo "  rebuild <user>  Force rebuild specific user's image"
        echo "  dns             Show DNS setup instructions"
        exit 1
        ;;
esac
