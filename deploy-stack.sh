#!/bin/bash

# Docker Swarm Stack Deployment Script
# Usage: ./deploy-stack.sh [start|stop|status|logs|update]

set -e

STACK_NAME="analytics"
COMPOSE_FILE="docker-stack.yml"
ENV_FILE=".env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker Swarm is initialized
check_swarm() {
    if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
        print_error "Docker Swarm is not initialized!"
        print_status "Initializing Docker Swarm..."
        docker swarm init
        print_success "Docker Swarm initialized"
    else
        print_success "Docker Swarm is active"
    fi
}

# Create .env file if it doesn't exist
create_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        print_status "Creating .env file..."
        cat > "$ENV_FILE" << EOF
# Database Configuration
MAIN_DB_USER=postgres
MAIN_DB_PASS=analytics123
MAIN_DB_NAME=main_db

HOLDING_DB_USER=postgres
HOLDING_DB_PASS=analytics123
HOLDING_DB_NAME=holding_db

# Dead Letter Queue
DLQ_DB_USER=dlq_user
DLQ_DB_PASS=dlq_password
DLQ_DB_NAME=dead_letter_queue

# API Security
API_KEY=analytics_demo_key_123

# Grafana Passwords
GRAFANA_PASSWORD=admin
GRAFANA_LOGS_PASSWORD=admin

# Docker Registry (update with your registry)
DOCKER_REGISTRY=your-username
EOF
        print_success ".env file created"
    else
        print_status ".env file already exists"
    fi
}

# Deploy the stack
deploy_stack() {
    print_status "Deploying $STACK_NAME stack..."
    
    # Check if stack already exists
    if docker stack ls --format "{{.Name}}" | grep -q "^$STACK_NAME$"; then
        print_warning "Stack $STACK_NAME already exists. Updating..."
        docker stack deploy -c "$COMPOSE_FILE" --with-registry-auth "$STACK_NAME"
    else
        print_status "Creating new stack $STACK_NAME..."
        docker stack deploy -c "$COMPOSE_FILE" --with-registry-auth "$STACK_NAME"
    fi
    
    print_success "Stack deployed successfully"
}

# Remove the stack
remove_stack() {
    print_status "Removing $STACK_NAME stack..."
    
    if docker stack ls --format "{{.Name}}" | grep -q "^$STACK_NAME$"; then
        docker stack rm "$STACK_NAME"
        print_success "Stack removed successfully"
        
        # Wait for services to stop
        print_status "Waiting for services to stop..."
        sleep 10
        
        # Remove volumes (optional)
        read -p "Do you want to remove volumes? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Removing volumes..."
            docker volume prune -f
            print_success "Volumes removed"
        fi
    else
        print_warning "Stack $STACK_NAME not found"
    fi
}

# Show stack status
show_status() {
    print_status "Stack Status:"
    echo
    docker stack ls
    echo
    print_status "Service Details:"
    docker stack services "$STACK_NAME" --format "table {{.Name}}\t{{.Mode}}\t{{.Replicas}}\t{{.Image}}\t{{.Ports}}"
    echo
    print_status "Service Health:"
    docker service ls --filter "label=com.docker.stack.namespace=$STACK_NAME" --format "table {{.Name}}\t{{.Replicas}}\t{{.UpdateStatus}}"
}

# Show logs
show_logs() {
    print_status "Available services:"
    docker stack services "$STACK_NAME" --format "{{.Name}}"
    echo
    read -p "Enter service name to view logs (or 'all' for all services): " service_name
    
    if [ "$service_name" = "all" ]; then
        print_status "Showing logs for all services..."
        docker stack services "$STACK_NAME" --format "{{.Name}}" | while read service; do
            echo "=== $service ==="
            docker service logs --tail 50 "$service" 2>/dev/null || true
            echo
        done
    else
        print_status "Showing logs for $service_name..."
        docker service logs --tail 100 -f "$service_name" 2>/dev/null || print_error "Service $service_name not found"
    fi
}

# Update stack
update_stack() {
    print_status "Updating $STACK_NAME stack..."
    
    # Pull latest images
    print_status "Pulling latest images..."
    docker stack services "$STACK_NAME" --format "{{.Image}}" | sort -u | while read image; do
        if [[ $image == *"analytics-infra"* ]]; then
            print_status "Pulling $image..."
            docker pull "$image" || print_warning "Failed to pull $image"
        fi
    done
    
    # Deploy updated stack
    deploy_stack
    
    print_success "Stack updated successfully"
}

# Show help
show_help() {
    echo "Docker Swarm Stack Deployment Script"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  start     Deploy the analytics stack"
    echo "  stop      Remove the analytics stack"
    echo "  status    Show stack and service status"
    echo "  logs      Show logs for services"
    echo "  update    Update the stack with latest images"
    echo "  help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0 start          # Deploy the stack"
    echo "  $0 status         # Check status"
    echo "  $0 logs api_receiver  # View API receiver logs"
    echo "  $0 stop           # Remove the stack"
}

# Main script logic
case "${1:-help}" in
    start)
        print_status "Starting Analytics Infrastructure Stack..."
        check_swarm
        create_env_file
        deploy_stack
        print_success "Stack started successfully!"
        print_status "Use '$0 status' to check service status"
        print_status "Use '$0 logs' to view service logs"
        ;;
    stop)
        print_status "Stopping Analytics Infrastructure Stack..."
        remove_stack
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    update)
        update_stack
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac

