#!/bin/bash

# Analytics Infrastructure Stack Startup Script
# This script starts all services in the correct dependency order

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

# Function to check if a service is healthy
check_service_health() {
    local service_name=$1
    local health_url=$2
    local max_attempts=${3:-30}
    local attempt=1

    print_status "Waiting for $service_name to be healthy..."

    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$health_url" > /dev/null 2>&1; then
            print_success "$service_name is healthy!"
            return 0
        fi

        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    print_error "$service_name failed to become healthy after $max_attempts attempts"
    return 1
}

# Function to wait for database to be ready
wait_for_database() {
    local db_name=$1
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for $db_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose exec -T "$db_name" pg_isready -U postgres > /dev/null 2>&1; then
            print_success "$db_name is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "$db_name failed to become ready after $max_attempts attempts"
    return 1
}

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_error ".env file not found!"
    print_status "Please create a .env file with the required environment variables."
    print_status "See SETUP.md for details."
    exit 1
fi

print_status "Starting Analytics Infrastructure Stack..."
echo "=================================================="

# Step 1: Start core databases first
print_status "Step 1: Starting core databases..."
docker-compose up -d postgres_main holding_db dead-letter-queue

# Wait for databases to be ready
wait_for_database "postgres_main"
wait_for_database "holding_db"
wait_for_database "dead-letter-queue"

# Generate fresh demo CSVs for each start
print_status "Generating fresh demo CSVs..."
mkdir -p ./demo_data
# Prefer project venv Python if available
PYTHON_BIN="python3"
if [ -x "./.venv/bin/python" ]; then
    PYTHON_BIN="./.venv/bin/python"
fi
"$PYTHON_BIN" ./scripts/generate_demo_data.py || {
    print_warning "Demo data generation failed; continuing without fresh CSVs"
}

# Create tables and import demo CSVs into main_db
print_status "Creating tables and importing CSVs into main_db..."
# Use container env vars to avoid host-side env expansion issues
docker-compose exec -T postgres_main bash -lc 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/schema.sql' || print_warning "Schema creation failed"
docker-compose exec -T postgres_main bash -lc 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/import.sql' || print_warning "CSV import failed"

# Step 2: Start logging infrastructure
print_status "Step 2: Starting logging infrastructure..."
docker-compose up -d loki promtail

# Wait for Loki to be ready
check_service_health "Loki" "http://localhost:3100/ready"

# Step 3: Start monitoring infrastructure
print_status "Step 3: Starting monitoring infrastructure..."
docker-compose up -d prometheus node-exporter postgres-exporter

# Wait for Prometheus to be ready
check_service_health "Prometheus" "http://localhost:9090/-/healthy"

# Step 4: Start data pipeline services
print_status "Step 4: Starting data pipeline services..."
docker-compose up -d api-receiver data-validator sync-job

# Wait for API receiver to be ready
check_service_health "API Receiver" "http://localhost:8080/health"

# Wait for data validator to be ready
check_service_health "Data Validator" "http://localhost:8082/health"

# Step 5: Backup visualization config before starting services
print_status "Step 5: Restoring visualization configs from latest backup (if present)..."
restore_from_latest_backup() {
    local backup_root="./visualization/backups"
    if [ ! -d "$backup_root" ]; then
        print_warning "No visualization backups directory found; skipping restore"
        return 0
    fi

    # Find latest timestamped backup directory
    local latest_dir
    latest_dir=$(find "$backup_root" -maxdepth 1 -type d -name "[0-9]*" | sort | tail -n 1 || true)
    if [ -z "$latest_dir" ]; then
        print_warning "No dated backups found in $backup_root; skipping restore"
        return 0
    fi

    print_status "Restoring from $latest_dir"

    # Restore Metabase data
    if [ -f "$latest_dir/metabase.tar.gz" ]; then
        mkdir -p ./visualization/metabase
        tar -xzf "$latest_dir/metabase.tar.gz" -C ./visualization
        print_success "Metabase data restored"
    else
        print_warning "metabase.tar.gz not found in backup; skipping Metabase restore"
    fi

    # Restore Grafana monitoring
    if [ -f "$latest_dir/grafana-monitoring.tar.gz" ]; then
        mkdir -p ./monitoring/grafana
        tar -xzf "$latest_dir/grafana-monitoring.tar.gz" -C ./monitoring
        print_success "Grafana monitoring data restored"
    else
        print_warning "grafana-monitoring.tar.gz not found in backup; skipping Grafana monitoring restore"
    fi

    # Restore Grafana logs
    if [ -f "$latest_dir/grafana-logs.tar.gz" ]; then
        mkdir -p ./logging/grafana-logs
        tar -xzf "$latest_dir/grafana-logs.tar.gz" -C ./logging
        print_success "Grafana logs data restored"
    else
        print_warning "grafana-logs.tar.gz not found in backup; skipping Grafana logs restore"
    fi
}

restore_from_latest_backup || print_warning "Visualization restore encountered issues"

# Clean up duplicate datasource files after restoration
print_status "Cleaning up duplicate datasource files after restoration..."
find ./monitoring/grafana/provisioning/datasources -name "prometheus*.yml" ! -name "prometheus.yml" -delete 2>/dev/null || true
find ./logging/grafana-logs/provisioning/datasources -name "loki*.yml" ! -name "loki.yml" -delete 2>/dev/null || true
print_success "Duplicate datasource files cleaned up"

# Step 6: Start visualization services
print_status "Step 6: Starting visualization services..."
print_status "Checking Metabase app DB migration (H2 -> Postgres)"
chmod +x ./scripts/migrate_metabase_h2_to_postgres.sh || true
./scripts/migrate_metabase_h2_to_postgres.sh || print_warning "Metabase migration step skipped or failed"
# Ensure Metabase application database exists (default: metabase)
print_status "Ensuring Metabase application database exists..."
docker-compose exec -T postgres_main bash -lc "
  DB_NAME=\${METABASE_APP_DB_NAME:-metabase}
  if [ -z \"\$DB_NAME\" ]; then DB_NAME=metabase; fi
  # Check database existence and create if missing
  if ! psql -U \"\$POSTGRES_USER\" -d postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='\$DB_NAME'\" | grep -q 1; then
    createdb -U \"\$POSTGRES_USER\" \"\$DB_NAME\" || true
  fi"

# If a DB dump exists in the latest backup, restore it when the target DB is empty
print_status "Checking for Metabase DB dump to restore..."
restore_metabase_db_from_backup() {
    local backup_root="./visualization/backups"
    local db_name
    db_name=$(docker-compose exec -T postgres_main bash -lc 'echo ${METABASE_APP_DB_NAME:-metabase}')

    if [ ! -d "$backup_root" ]; then
        print_warning "No visualization backups directory found; skipping DB restore"
        return 0
    fi

    local latest_dir
    latest_dir=$(find "$backup_root" -maxdepth 1 -type d -name "[0-9]*" | sort | tail -n 1 || true)
    if [ -z "$latest_dir" ]; then
        print_warning "No dated backups found in $backup_root; skipping DB restore"
        return 0
    fi

    if [ ! -f "$latest_dir/metabase.sql.gz" ]; then
        print_status "No metabase.sql.gz found in $latest_dir; skipping DB restore"
        return 0
    fi

    print_status "Restoring Metabase DB from latest dump (force-restore)..."
    # Drop and recreate DB to ensure a clean state
    docker-compose exec -T postgres_main bash -lc "psql -v ON_ERROR_STOP=1 -U \"\$POSTGRES_USER\" -d postgres -c \"DROP DATABASE IF EXISTS '$db_name';\" -c \"CREATE DATABASE '$db_name';\"" \
      || print_warning "Failed to recreate Metabase DB; attempting restore anyway"

    gunzip -c "$latest_dir/metabase.sql.gz" | docker-compose exec -T postgres_main bash -lc "psql -U \"\$POSTGRES_USER\" -d '$db_name'" \
      && print_success "Metabase DB restored from backup" \
      || print_warning "Metabase DB restore failed"
}

if [ "${RESTORE_METABASE_ON_START:-true}" = "true" ]; then
    print_status "RESTORE_METABASE_ON_START=true → restoring DB from latest backup"
    restore_metabase_db_from_backup
else
    print_status "RESTORE_METABASE_ON_START=false → skipping DB restore"
fi
docker-compose up -d metabase

# Wait for Metabase to be ready (Metabase can take longer on first start)
check_service_health "Metabase" "http://localhost:3000/api/health" 120

# Step 7: Start Grafana services
print_status "Step 7: Starting Grafana services..."
docker-compose up -d grafana grafana-logs

# Wait for Grafana services to be ready
check_service_health "Grafana Monitoring" "http://localhost:3001/api/health"
check_service_health "Grafana Logs" "http://localhost:3002/api/health"

# Step 8: Start health monitor (depends on all other services)
print_status "Step 8: Starting health monitor..."
docker-compose up -d health-monitor

# Wait for health monitor to be ready
check_service_health "Health Monitor" "http://localhost:8083/health"

echo "=================================================="
print_success "All services started successfully!"

# Display service status
print_status "Service Status:"
docker-compose ps

echo ""
print_status "Access Points:"
echo "  📊 Metabase Dashboards:     http://localhost:3000"
echo "  📈 Grafana Monitoring:      http://localhost:3001"
echo "  📝 Grafana Logs:            http://localhost:3002"
echo "  🔍 Prometheus:              http://localhost:9090"
echo "  🏥 Health Monitor:          http://localhost:8083"
echo "  📡 API Receiver:            http://localhost:8080"
echo "  ✅ Data Validator:          http://localhost:8082"
echo "  🔄 Sync Job Metrics:        http://localhost:8081"

echo ""
print_status "Quick Health Check:"
if curl -s -f "http://localhost:8083/health" > /dev/null; then
    print_success "Overall system health: HEALTHY"
else
    print_warning "Overall system health: CHECKING..."
fi

echo ""
print_status "To view logs: docker-compose logs -f [service-name]"
print_status "To stop all services: docker-compose down"
print_status "To restart a service: docker-compose restart [service-name]"

echo ""
print_success "Analytics Infrastructure Stack is ready! 🚀"
