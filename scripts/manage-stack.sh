#!/bin/bash

# Docker Stack management script for analytics-infra-demo
# Usage: ./manage-stack.sh [deploy|remove|status|logs|update]

set -e

STACK_NAME="analytics-stack"
COMPOSE_FILE="docker-stack.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_header() {
    echo -e "${BLUE}[STACK]${NC} $1"
}

show_usage() {
    echo "Usage: $0 [deploy|remove|status|logs|update|scale|restart]"
    echo ""
    echo "Commands:"
    echo "  deploy   - Deploy the stack (same as deploy-stack.sh)"
    echo "  remove   - Remove the stack completely"
    echo "  status   - Show stack and service status"
    echo "  logs     - Show logs for a specific service"
    echo "  update   - Update the stack with new configuration"
    echo "  scale    - Scale a specific service"
    echo "  restart  - Restart a specific service"
    echo ""
    echo "Examples:"
    echo "  $0 deploy"
    echo "  $0 status"
    echo "  $0 logs api-receiver"
    echo "  $0 scale api-receiver 3"
    echo "  $0 restart metabase"
}

check_stack_exists() {
    if ! docker stack ls | grep -q "$STACK_NAME"; then
        echo_error "Stack '$STACK_NAME' is not deployed"
        return 1
    fi
}

deploy_stack() {
    echo_header "Deploying stack: $STACK_NAME"
    ./scripts/deploy-stack.sh
}

remove_stack() {
    echo_header "Removing stack: $STACK_NAME"
    if check_stack_exists; then
        echo_warn "This will remove all services in the stack. Data in volumes will be preserved."
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker stack rm "$STACK_NAME"
            echo_info "Stack removed successfully"
        else
            echo_info "Operation cancelled"
        fi
    fi
}

show_status() {
    echo_header "Stack status for: $STACK_NAME"
    
    if check_stack_exists; then
        echo ""
        echo_info "Stack overview:"
        docker stack ls | grep "$STACK_NAME" || echo_warn "Stack not found"
        
        echo ""
        echo_info "Service status:"
        docker stack services "$STACK_NAME"
        
        echo ""
        echo_info "Task status:"
        docker stack ps "$STACK_NAME" --no-trunc
    fi
}

show_logs() {
    local service_name="$1"
    if [[ -z "$service_name" ]]; then
        echo_error "Please specify a service name"
        echo_info "Available services:"
        docker stack services "$STACK_NAME" --format "table {{.Name}}" | tail -n +2
        return 1
    fi
    
    local full_service_name="${STACK_NAME}_${service_name}"
    echo_header "Logs for service: $service_name"
    docker service logs -f "$full_service_name"
}

update_stack() {
    echo_header "Updating stack: $STACK_NAME"
    if check_stack_exists; then
        echo_info "Redeploying stack with updated configuration..."
        docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME"
        echo_info "Stack updated successfully"
    fi
}

scale_service() {
    local service_name="$1"
    local replicas="$2"
    
    if [[ -z "$service_name" ]] || [[ -z "$replicas" ]]; then
        echo_error "Usage: $0 scale <service_name> <replicas>"
        echo_info "Available services:"
        docker stack services "$STACK_NAME" --format "table {{.Name}}" | tail -n +2
        return 1
    fi
    
    local full_service_name="${STACK_NAME}_${service_name}"
    echo_header "Scaling service: $service_name to $replicas replicas"
    docker service scale "$full_service_name=$replicas"
}

restart_service() {
    local service_name="$1"
    
    if [[ -z "$service_name" ]]; then
        echo_error "Please specify a service name"
        echo_info "Available services:"
        docker stack services "$STACK_NAME" --format "table {{.Name}}" | tail -n +2
        return 1
    fi
    
    local full_service_name="${STACK_NAME}_${service_name}"
    echo_header "Restarting service: $service_name"
    docker service update --force "$full_service_name"
}

# Main script logic
case "$1" in
    deploy)
        deploy_stack
        ;;
    remove)
        remove_stack
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    update)
        update_stack
        ;;
    scale)
        scale_service "$2" "$3"
        ;;
    restart)
        restart_service "$2"
        ;;
    *)
        show_usage
        exit 1
        ;;
esac


