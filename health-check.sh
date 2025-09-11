#!/bin/bash

# Health check script for Dokploy deployment
# This script checks the health of all services

set -e

echo "🔍 Starting health checks..."

# Function to check if a service is healthy
check_service() {
    local service_name=$1
    local port=$2
    local endpoint=${3:-"/"}
    
    echo "Checking $service_name on port $port..."
    
    if curl -f -s "http://localhost:$port$endpoint" > /dev/null; then
        echo "✅ $service_name is healthy"
        return 0
    else
        echo "❌ $service_name is unhealthy"
        return 1
    fi
}

# Check all services
services_healthy=true

# Database services
check_service "PostgreSQL Main" 5432 || services_healthy=false

# Monitoring services
check_service "Prometheus" 9090 "/-/healthy" || services_healthy=false
check_service "Grafana" 3001 "/api/health" || services_healthy=false
check_service "Grafana Logs" 3002 "/api/health" || services_healthy=false

# Logging services
check_service "Loki" 3100 "/ready" || services_healthy=false

# Visualization services
check_service "Metabase" 3000 "/api/health" || services_healthy=false

# Summary
if [ "$services_healthy" = true ]; then
    echo "🎉 All services are healthy!"
    exit 0
else
    echo "⚠️  Some services are unhealthy!"
    exit 1
fi
