# Stack Management Guide

This guide covers the management scripts and commands for the Analytics Infrastructure Stack.

## Table of Contents

- [Available Scripts](#available-scripts)
  - [1. Main Management Script - manage-stack.sh](#1-main-management-script---manage-stacksh)
  - [2. Startup Script - start-stack.sh](#2-startup-script---start-stacksh)
  - [3. Shutdown Script - stop-stack.sh](#3-shutdown-script---stop-stacksh)
  - [4. Status Check Script - check-stack.sh](#4-status-check-script---check-stacksh)
- [Quick Start Examples](#quick-start-examples)
  - [Start the Stack](#start-the-stack)
  - [Check Status](#check-status)
  - [View Logs](#view)
  - [Restart Services](#restart-services)
- [Service Management](#service-management)
  - [Individual Service Control](#individual-service-control)
  - [Database Management](#database-management)
- [Monitoring & Debugging](#monitoring--debugging)
  - [Health Checks](#health-checks)
  - [Metrics Access](#metrics-access)
  - [Log Analysis](#log-analysis)
- [Demo Data Management](#demo-data-management)
  - [Generating Demo Data](#generating-demo-data)
  - [Demo Data Contents](#demo-data-contents)
  - [Data Management Commands](#data-management-commands)
- [Data Management](#data-management)
  - [Data Validation](#data-validation)
  - [Data Ingestion](#data-ingestion)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
  - [Cleanup Operations](#cleanup-operations)
- [Security](#security)
  - [Environment Variables](#environment-variables)
  - [Network Security](#network-security)
- [Performance Monitoring](#performance-monitoring)
  - [Resource Monitoring](#resource-monitoring)
  - [Performance Testing](#performance-testing)
- [Emergency Procedures](#emergency-procedures)
  - [Complete Reset](#complete-reset)
  - [Data Recovery](#data-recovery)
- [Additional Resources](#additional-resources)
- [Support](#support)

## Available Scripts

### 1. **Main Management Script** - `manage-stack.sh`

The primary interface for managing the entire stack.

```bash
./manage-stack.sh [COMMAND]
```

**Commands:**

- `start` - Start the entire stack in correct order
- `stop` - Stop all services gracefully  
- `restart` - Restart the entire stack
- `status` - Check health of all services
- `logs` - Show logs for services
- `clean` - Stop and remove all containers/volumes
- `build` - Rebuild all custom images
- `services` - List all available services
- `help` - Show help message

### 2. **Startup Script** - `start-stack.sh`

Starts all services in the correct dependency order with health checks.

```bash
./start-stack.sh
```

**Features:**

- ✅ Dependency-aware startup order
- ✅ Health checks for each service
- ✅ Colored output and progress indicators
- ✅ Automatic retry logic
- ✅ Service status verification
- ✅ Optional demo data generation
- ✅ Interactive data setup choices

### 3. **Shutdown Script** - `stop-stack.sh`

Stops all services gracefully in reverse dependency order.

```bash
./stop-stack.sh
```

**Features:**

- ✅ Graceful shutdown order
- ✅ Service status reporting
- ✅ Clean container termination

### 4. **Status Check Script** - `check-stack.sh`

Comprehensive health check for all services.

```bash
./check-stack.sh
```

**Features:**

- ✅ Service health verification
- ✅ Port accessibility checks
- ✅ Database status monitoring
- ✅ Metrics availability check
- ✅ Access URL display

## Quick Start Examples

### Start the Stack

```bash
# Start everything (recommended)
./manage-stack.sh start
# Choose 'y' for demo data or 'n' for empty database

# Or use the dedicated script
./start-stack.sh
# Will prompt for demo data generation after services start
```

### Check Status

```bash
# Quick health check
./manage-stack.sh status

# Or use the dedicated script
./check-stack.sh
```

### View

```bash
# All services
./manage-stack.sh logs

# Specific service
./manage-stack.sh logs api-receiver
./manage-stack.sh logs data-validator
./manage-stack.sh logs sync-job
```

### Restart Services

```bash
# Restart everything
./manage-stack.sh restart

# Restart specific service
docker-compose restart api-receiver
```

## Service Management

### Individual Service Control

```bash
# Start specific service
docker-compose up -d api-receiver

# Stop specific service
docker-compose stop api-receiver

# Restart specific service
docker-compose restart api-receiver

# View logs for specific service
docker-compose logs -f api-receiver

# Check service status
docker-compose ps api-receiver
```

### Database Management

```bash
# Connect to main database
docker-compose exec postgres_main psql -U postgres -d main_db

# Connect to holding database
docker-compose exec holding_db psql -U postgres -d holding_db

# Connect to dead letter queue
docker-compose exec dead_letter_queue psql -U dlq_user -d dead_letter_queue

# Backup main database
docker-compose exec postgres_main pg_dump -U postgres main_db > backup.sql

# Restore main database
docker-compose exec -T postgres_main psql -U postgres main_db < backup.sql
```

## Monitoring & Debugging

### Health Checks

```bash
# Overall system health
curl http://localhost:8083/health

# Individual service health
curl http://localhost:8080/health  # API Receiver
curl http://localhost:8082/health  # Data Validator
curl http://localhost:3000/api/health  # Metabase
```

### Metrics Access

```bash
# Prometheus metrics
curl http://localhost:9090/metrics

# Service-specific metrics
curl http://localhost:8080/metrics  # API Receiver
curl http://localhost:8082/metrics  # Data Validator
curl http://localhost:8081/metrics  # Sync Job
```

### Log Analysis

```bash
# Real-time logs
./manage-stack.sh logs

# Historical logs
docker-compose logs --since="1h" api-receiver

# Error logs only
docker-compose logs api-receiver | grep ERROR

# Logs with timestamps
docker-compose logs -t api-receiver
```

## Demo Data Management

### Generating Demo Data

```bash
# Start stack with demo data generation
./manage-stack.sh start
# Choose 'y' when prompted for demo data generation

# Or run data generation manually
python3 ./scripts/generate_demo_data.py
```

### Demo Data Contents

The system generates realistic sample data including:

- **In-store Sales**: 1,500 transaction records
- **Online Sales**: 2,000 e-commerce orders
- **Marketing Email**: 60 days of email campaign metrics
- **Marketing TikTok**: 60 days of social media data
- **Photo Production**: 250 creative production jobs

### Data Management Commands

```bash
# Clear all demo data
docker-compose exec postgres_main psql -U postgres -d main_db -c "TRUNCATE TABLE merch.instore_sales, merch.online_sales, merch.marketing_email_daily, merch.marketing_tiktok_daily, merch.photo_production CASCADE;"

# Import fresh demo data
docker-compose exec postgres_main psql -U postgres -d main_db -f /sql/import.sql

# Check data counts
docker-compose exec postgres_main psql -U postgres -d main_db -c "SELECT 'instore_sales' as table_name, COUNT(*) as count FROM merch.instore_sales UNION ALL SELECT 'online_sales', COUNT(*) FROM merch.online_sales UNION ALL SELECT 'marketing_email_daily', COUNT(*) FROM merch.marketing_email_daily UNION ALL SELECT 'marketing_tiktok_daily', COUNT(*) FROM merch.marketing_tiktok_daily UNION ALL SELECT 'photo_production', COUNT(*) FROM merch.photo_production;"
```

## Data Management

### Data Validation

```bash
# Check validation stats
curl http://localhost:8082/dlq/stats

# Validate data via API
curl -X POST http://localhost:8082/validate \
  -H "Content-Type: application/json" \
  -d '{"sale_id": "S123", "sale_date": "2024-01-01T00:00:00Z", ...}'
```

### Data Ingestion

```bash
# Send test data
curl -X POST http://localhost:8080/ingest \
  -H "Content-Type: application/json" \
  -H "x-api-key: your_api_key" \
  -d '{"sale_id": "S123", "customer_id": 1, ...}'
```

## Troubleshooting

### Common Issues

1. **Services won't start**

   ```bash
   # Check logs
   ./manage-stack.sh logs
   
   # Check Docker status
   docker-compose ps
   
   # Restart specific service
   docker-compose restart [service-name]
   ```

2. **Database connection issues**

   ```bash
   # Check database status
   docker-compose exec postgres_main pg_isready
   
   # Check network connectivity
   docker-compose exec api-receiver ping postgres_main
   ```

3. **Port conflicts**

   ```bash
   # Check what's using ports
   lsof -i :8080
   lsof -i :3000
   
   # Stop conflicting services
   sudo lsof -ti:8080 | xargs kill -9
   ```

4. **High resource usage**

   ```bash
   # Check resource usage
   docker stats
   
   # Restart services
   ./manage-stack.sh restart
   ```

### Cleanup Operations

```bash
# Stop and remove containers
./manage-stack.sh clean

# Remove specific volumes
docker-compose down -v

# Remove orphaned containers
docker-compose down --remove-orphans

# Clean up Docker system
docker system prune -a
```

## Security

### Environment Variables

```bash
# Generate secure passwords
openssl rand -base64 32

# Generate secure API key
openssl rand -hex 32

# Check .env file
cat .env | grep -v PASSWORD  # Show non-sensitive vars
```

### Network Security

```bash
# Check exposed ports
docker-compose ps

# Verify localhost binding
netstat -tlnp | grep :8080
netstat -tlnp | grep :3000
```

## Performance Monitoring

### Resource Monitoring

```bash
# Container resource usage
docker stats

# System resource usage
htop
iostat -x 1

# Disk usage
df -h
du -sh ./data/*
```

### Performance Testing

```bash
# Load test API
for i in {1..100}; do
  curl -X POST http://localhost:8080/ingest \
    -H "Content-Type: application/json" \
    -H "x-api-key: your_api_key" \
    -d '{"sale_id": "S'$i'", "customer_id": 1, ...}'
done
```

## Emergency Procedures

### Complete Reset

```bash
# Stop everything
./manage-stack.sh stop

# Remove all data
./manage-stack.sh clean

# Rebuild images
./manage-stack.sh build

# Start fresh
./manage-stack.sh start
```

### Data Recovery

```bash
# Backup before changes
docker-compose exec postgres_main pg_dump -U postgres main_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
docker-compose exec -T postgres_main psql -U postgres main_db < backup_20240101_120000.sql
```

## Additional Resources

- **SETUP.md** - Initial setup and configuration
- **README.md** - Project overview and architecture
- **docs/SECURITY.md** - Security best practices

## Support

For issues or questions:

1. Check logs: `./manage-stack.sh logs`
2. Verify health: `./manage-stack.sh status`
3. Review metrics: <http://localhost:3001>
4. Check logs: <http://localhost:3002>
