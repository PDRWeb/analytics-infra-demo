#!/bin/bash

# Analytics Infrastructure Stack Shutdown Script
# This script stops all services in the correct order

set -e  # Exit on any error

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

print_status "Stopping Analytics Infrastructure Stack..."
echo "=================================================="

# Pre-stop: create a fresh visualization backup (Metabase DB + configs)
print_status "Creating pre-shutdown visualization backup..."
chmod +x ./scripts/backup_visualization.sh || true
./scripts/backup_visualization.sh || print_warning "Backup failed; continuing shutdown"

# Step 1: Stop health monitor first (depends on all other services)
print_status "Step 1: Stopping health monitor..."
docker-compose stop health-monitor

# Step 2: Stop Grafana services
print_status "Step 2: Stopping Grafana services..."
docker-compose stop grafana grafana-logs

# Step 3: Stop visualization services
print_status "Step 3: Stopping visualization services..."
docker-compose stop metabase

# Step 4: Stop data pipeline services
print_status "Step 4: Stopping data pipeline services..."
docker-compose stop api-receiver data-validator sync-job

# Step 5: Stop monitoring infrastructure
print_status "Step 5: Stopping monitoring infrastructure..."
docker-compose stop prometheus node-exporter postgres-exporter

# Step 6: Stop logging infrastructure
print_status "Step 6: Stopping logging infrastructure..."
docker-compose stop loki promtail

# Step 7: Stop databases last
print_status "Step 7: Stopping databases..."
docker-compose stop postgres_main holding_db dead-letter-queue

echo "=================================================="
print_success "All services stopped successfully!"

# Display final status
print_status "Final Service Status:"
docker-compose ps

echo ""
print_status "To completely remove containers and volumes:"
print_status "  docker-compose down -v"
print_status ""
print_status "To restart the stack:"
print_status "  ./start-stack.sh"

echo ""
print_success "Analytics Infrastructure Stack stopped!"
