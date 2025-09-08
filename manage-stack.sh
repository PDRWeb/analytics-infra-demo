#!/bin/bash

# Analytics Infrastructure Stack Management Script
# This script provides a unified interface to manage the entire stack

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${PURPLE}  Analytics Infrastructure Stack Manager${NC}"
    echo -e "${PURPLE}================================================${NC}"
}

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     Start the entire stack in correct order"
    echo "  stop      Stop all services gracefully"
    echo "  restart   Restart the entire stack"
    echo "  status    Check health of all services"
    echo "  logs      Show logs for all services"
    echo "  clean     Stop and remove all containers/volumes"
    echo "  build     Rebuild all custom images"
    echo "  backup    Create a visualization backup (Metabase DB + configs)"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start          # Start the entire stack"
    echo "  $0 status         # Check service health"
    echo "  $0 logs api       # Show logs for API receiver"
    echo "  $0 logs           # Show logs for all services"
}

# Function to start the stack
start_stack() {
    print_status "Starting Analytics Infrastructure Stack..."
    ./start-stack.sh
}

# Function to stop the stack
stop_stack() {
    print_status "Stopping Analytics Infrastructure Stack..."
    ./stop-stack.sh
}

# Function to restart the stack
restart_stack() {
    print_status "Restarting Analytics Infrastructure Stack..."
    ./stop-stack.sh
    sleep 5
    ./start-stack.sh
}

# Function to check status
check_status() {
    print_status "Checking Analytics Infrastructure Stack Status..."
    ./check-stack.sh
}

# Function to show logs
show_logs() {
    local service=$1
    
    if [ -z "$service" ]; then
        print_status "Showing logs for all services..."
        docker-compose logs -f
    else
        print_status "Showing logs for $service..."
        docker-compose logs -f "$service"
    fi
}

# Function to clean everything
clean_stack() {
    print_warning "This will stop and remove ALL containers, networks, and volumes!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleaning up all containers and volumes..."
        docker-compose down -v --remove-orphans

        # Also remove stray/duplicate Grafana datasource files that can break provisioning
        print_status "Removing duplicate Grafana datasource files (keeping canonical files) ..."
        MON_DS_DIR="./monitoring/grafana/provisioning/datasources"
        LOG_DS_DIR="./logging/grafana-logs/provisioning/datasources"

        if [ -d "$MON_DS_DIR" ]; then
            # Keep prometheus.yml; remove other "prometheus*.yml" duplicates
            find "$MON_DS_DIR" -type f -name 'prometheus*.yml' ! -name 'prometheus.yml' -print -delete || true
        fi

        if [ -d "$LOG_DS_DIR" ]; then
            # Keep loki.yml; remove other "loki*.yml" duplicates
            find "$LOG_DS_DIR" -type f -name 'loki*.yml' ! -name 'loki.yml' -print -delete || true
        fi

        print_success "Cleanup completed!"
    else
        print_status "Cleanup cancelled."
    fi
}

# Function to rebuild images
rebuild_images() {
    print_status "Rebuilding all custom images..."
    docker-compose build --no-cache
    print_success "Images rebuilt successfully!"
}

# Function to run backup on demand
run_backup() {
    print_status "Creating visualization backup..."
    chmod +x ./scripts/backup_visualization.sh || true
    ./scripts/backup_visualization.sh
    print_success "Backup completed."
}

# Function to show service list
show_services() {
    print_status "Available services:"
    echo ""
    echo "Core Pipeline:"
    echo "  - api-receiver      (Port 8080) - API data ingestion"
    echo "  - holding_db        - Temporary data storage"
    echo "  - data-validator    (Port 8082) - Data validation"
    echo "  - sync-job          (Port 8081) - Data synchronization"
    echo "  - postgres_main     (Port 5432) - Main database"
    echo "  - metabase          (Port 3000) - Business dashboards"
    echo ""
    echo "Monitoring:"
    echo "  - prometheus        (Port 9090) - Metrics collection"
    echo "  - grafana           (Port 3001) - Monitoring dashboards"
    echo "  - node-exporter     (Port 9100) - System metrics"
    echo "  - postgres-exporter (Port 9187) - Database metrics"
    echo "  - health-monitor    (Port 8083) - Health checks"
    echo ""
    echo "Logging:"
    echo "  - loki              (Port 3100) - Log aggregation"
    echo "  - promtail          - Log shipping"
    echo "  - grafana-logs      (Port 3002) - Log dashboards"
    echo ""
    echo "Validation:"
    echo "  - dead-letter-queue - Failed validation storage"
}

# Main script logic
print_header

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_error ".env file not found!"
    print_status "Please create a .env file with the required environment variables."
    print_status "See SETUP.md for details."
    exit 1
fi

# Parse command
case "${1:-help}" in
    start)
        start_stack
        ;;
    stop)
        stop_stack
        ;;
    restart)
        restart_stack
        ;;
    status)
        check_status
        ;;
    logs)
        show_logs "$2"
        ;;
    clean)
        clean_stack
        ;;
    build)
        rebuild_images
        ;;
    backup)
        run_backup
        ;;
    services)
        show_services
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
