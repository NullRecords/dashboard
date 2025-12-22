#!/bin/bash
# deploy-dashboard.sh - Deploy Personal Dashboard with Docker
#
# Usage:
#   ./deploy-dashboard.sh [command] [options]
#
# Commands:
#   up        Start the dashboard (default)
#   down      Stop the dashboard
#   restart   Restart the dashboard
#   logs      View logs
#   backup    Trigger manual backup
#   status    Show container status
#   shell     Open shell in container
#   build     Rebuild the image
#   pull      Pull latest code and rebuild

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.multi.yml"
ENV_FILE="$SCRIPT_DIR/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check for required files
check_requirements() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "docker-compose.multi.yml not found at $COMPOSE_FILE"
        exit 1
    fi
    
    if [ ! -f "$ENV_FILE" ]; then
        log_warn ".env file not found. Creating from template..."
        if [ -f "$SCRIPT_DIR/.env.example" ]; then
            cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
            log_info "Created .env file. Please edit it with your configuration."
            log_info "  nano $ENV_FILE"
            exit 1
        else
            log_error ".env.example not found. Cannot create .env file."
            exit 1
        fi
    fi
    
    # Check if docker is running
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Load user from .env
load_config() {
    if [ -f "$ENV_FILE" ]; then
        export $(grep -v '^#' "$ENV_FILE" | xargs)
    fi
    DASHBOARD_USER="${DASHBOARD_USER:-parker}"
    CONTAINER_NAME="dashboard-${DASHBOARD_USER}"
}

cmd_up() {
    log_info "Starting dashboard for user: $DASHBOARD_USER"
    cd "$PROJECT_DIR"
    
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    
    log_success "Dashboard started!"
    log_info "Access at: http://${DASHBOARD_HOSTNAME:-localhost}:${DASHBOARD_PORT:-8020}"
    
    # Wait and check health
    log_info "Waiting for health check..."
    sleep 10
    if curl -s "http://localhost:${DASHBOARD_PORT:-8020}/api/health" | grep -q "healthy"; then
        log_success "Dashboard is healthy!"
    else
        log_warn "Health check pending. Check logs with: $0 logs"
    fi
}

cmd_down() {
    log_info "Stopping dashboard..."
    cd "$PROJECT_DIR"
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down
    log_success "Dashboard stopped"
}

cmd_restart() {
    log_info "Restarting dashboard..."
    cmd_down
    sleep 2
    cmd_up
}

cmd_logs() {
    SERVICE="${1:-dashboard-parker}"
    log_info "Showing logs for $SERVICE (Ctrl+C to exit)..."
    cd "$PROJECT_DIR"
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" logs -f "$SERVICE"
}

cmd_backup() {
    log_info "Triggering manual backup..."
    docker exec "$CONTAINER_NAME" /app/nightly-backup.sh
    log_success "Backup complete"
}

cmd_status() {
    log_info "Container status:"
    cd "$PROJECT_DIR"
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps
    
    echo ""
    log_info "Volume usage:"
    docker volume ls | grep dashboard
    
    echo ""
    log_info "Health check:"
    if curl -s "http://localhost:${DASHBOARD_PORT:-8020}/api/health" 2>/dev/null | grep -q "healthy"; then
        log_success "Dashboard is healthy"
    else
        log_warn "Dashboard is not responding"
    fi
}

cmd_shell() {
    log_info "Opening shell in $CONTAINER_NAME..."
    docker exec -it "$CONTAINER_NAME" /bin/bash
}

cmd_build() {
    log_info "Rebuilding dashboard image..."
    cd "$PROJECT_DIR"
    docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" build --no-cache
    log_success "Build complete"
}

cmd_pull() {
    log_info "Pulling latest code..."
    cd "$PROJECT_DIR"
    
    git fetch origin
    CURRENT_BRANCH=$(git branch --show-current)
    git pull origin "$CURRENT_BRANCH"
    
    log_info "Rebuilding..."
    cmd_build
    
    log_info "Restarting..."
    cmd_restart
    
    log_success "Update complete!"
}

cmd_help() {
    echo "Personal Dashboard Docker Deployment"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  up        Start the dashboard (default)"
    echo "  down      Stop the dashboard"
    echo "  restart   Restart the dashboard"
    echo "  logs      View logs (optional: service name)"
    echo "  backup    Trigger manual backup"
    echo "  status    Show container status"
    echo "  shell     Open shell in container"
    echo "  build     Rebuild the image"
    echo "  pull      Pull latest code and rebuild"
    echo "  help      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 up               # Start dashboard"
    echo "  $0 logs             # View dashboard logs"
    echo "  $0 logs ollama      # View ollama logs"
    echo "  $0 backup           # Manual backup"
    echo ""
}

# Main
check_requirements
load_config

COMMAND="${1:-up}"
shift || true

case "$COMMAND" in
    up)      cmd_up ;;
    down)    cmd_down ;;
    restart) cmd_restart ;;
    logs)    cmd_logs "$@" ;;
    backup)  cmd_backup ;;
    status)  cmd_status ;;
    shell)   cmd_shell ;;
    build)   cmd_build ;;
    pull)    cmd_pull ;;
    help|--help|-h)  cmd_help ;;
    *)
        log_error "Unknown command: $COMMAND"
        cmd_help
        exit 1
        ;;
esac
