#!/bin/bash

# Analytics Infrastructure Stack Status Check Script
# This script checks the health of all services

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

# Function to check service health
check_service() {
    local service_name=$1
    local health_url=$2
    local port=$3
    
    if curl -s -f "$health_url" > /dev/null 2>&1; then
        print_success "$service_name (Port $port): HEALTHY"
        return 0
    else
        print_error "$service_name (Port $port): UNHEALTHY"
        return 1
    fi
}

print_status "Analytics Infrastructure Stack Health Check"
echo "=================================================="

# Check if docker-compose is running
if ! docker-compose ps | grep -q "Up"; then
    print_error "No services are currently running!"
    print_status "Run './start-stack.sh' to start the stack."
    exit 1
fi

echo ""
print_status "Service Health Status:"
echo "------------------------"

# Check core services
check_service "API Receiver" "http://localhost:8080/health" "8080"
check_service "Data Validator" "http://localhost:8082/health" "8082"
check_service "Health Monitor" "http://localhost:8083/health" "8083"

echo ""
print_status "Monitoring Services:"
echo "----------------------"
check_service "Prometheus" "http://localhost:9090/-/healthy" "9090"
check_service "Grafana Monitoring" "http://localhost:3001/api/health" "3001"

echo ""
print_status "Logging Services:"
echo "------------------"
check_service "Loki" "http://localhost:3100/ready" "3100"
check_service "Grafana Logs" "http://localhost:3002/api/health" "3002"

echo ""
print_status "Visualization Services:"
echo "-------------------------"
check_service "Metabase" "http://localhost:3000/api/health" "3000"

echo ""
print_status "Database Status:"
echo "-----------------"

# Check database containers
if docker-compose ps | grep -q "postgres_main.*Up"; then
    print_success "Main Database: RUNNING"
else
    print_error "Main Database: NOT RUNNING"
fi

if docker-compose ps | grep -q "holding_db.*Up"; then
    print_success "Holding Database: RUNNING"
else
    print_error "Holding Database: NOT RUNNING"
fi

if docker-compose ps | grep -q "dead_letter_queue.*Up"; then
    print_success "Dead Letter Queue: RUNNING"
else
    print_error "Dead Letter Queue: NOT RUNNING"
fi

echo ""
print_status "Container Status:"
echo "------------------"
docker-compose ps

echo ""
print_status "Quick Metrics:"
echo "---------------"

# Check if we can get metrics
if curl -s -f "http://localhost:8080/metrics" > /dev/null 2>&1; then
    print_success "API Receiver metrics: AVAILABLE"
else
    print_warning "API Receiver metrics: NOT AVAILABLE"
fi

if curl -s -f "http://localhost:8082/metrics" > /dev/null 2>&1; then
    print_success "Data Validator metrics: AVAILABLE"
else
    print_warning "Data Validator metrics: NOT AVAILABLE"
fi

echo ""
print_status "Access URLs:"
echo "------------"
echo "  Metabase Dashboards:       http://localhost:3000"
echo "  Grafana Monitoring:        http://localhost:3001"
echo "  Grafana Logs:              http://localhost:3002"
echo "  Prometheus:                http://localhost:9090"
echo "  Health Monitor:            http://localhost:8083"
echo "  API Receiver:              http://localhost:8080"
echo "  Data Validator:            http://localhost:8082"
echo "  Sync Job Metrics:          http://localhost:8081"

echo ""
print_status "Useful Commands:"
echo "-----------------"
echo "  View logs:           docker-compose logs -f [service-name]"
echo "  Restart service:     docker-compose restart [service-name]"
echo "  Stop stack:          ./stop-stack.sh"
echo "  Start stack:         ./start-stack.sh"

echo ""
print_success "Health check completed!"
