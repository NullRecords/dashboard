#!/bin/bash
#
# Deploy Family Dashboards
# Builds and runs all family member dashboards with Traefik reverse proxy
#
# Usage:
#   ./deploy-family.sh           # Build and start all
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
    
    echo -e "${GREEN}🔨 Building and starting all dashboards...${NC}"
    echo ""
    
    docker-compose -f docker-compose.family.yml up -d --build
    
    echo ""
    echo -e "${GREEN}✅ All dashboards started!${NC}"
    echo ""
    status
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
    docker-compose -f docker-compose.family.yml up -d --build "dashboard-$user"
    echo -e "${GREEN}✅ $user's dashboard rebuilt and restarted.${NC}"
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
    stop|down)
        stop
        ;;
    restart)
        restart
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
        echo "Usage: $0 {start|stop|restart|logs|status|rebuild|dns}"
        echo ""
        echo "Commands:"
        echo "  start           Build and start all dashboards"
        echo "  stop            Stop all dashboards"
        echo "  restart         Restart all dashboards"
        echo "  logs [user]     View logs (optionally for specific user)"
        echo "  status          Show dashboard status"
        echo "  rebuild <user>  Rebuild specific user's dashboard"
        echo "  dns             Show DNS setup instructions"
        exit 1
        ;;
esac
