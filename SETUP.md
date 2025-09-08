# Analytics Infrastructure Setup Guide 🚀

This guide will help you set up the complete analytics infrastructure with monitoring, logging, and data validation.

## 🏗️ Architecture Overview

The infrastructure now includes:

### Core Data Pipeline
- **API Receiver** (Port 8080) - Receives data from external sources
- **Holding Database** - Temporary storage for incoming data
- **Data Validator** (Port 8082) - Validates data quality and schema
- **Sync Job** (Port 8081) - Syncs validated data to main database
- **Main Database** (Port 5432) - Authoritative data store
- **Metabase** (Port 3000) - Business intelligence dashboards

### Monitoring Stack
- **Prometheus** (Port 9090) - Metrics collection and alerting
- **Grafana** (Port 3001) - Monitoring dashboards
- **Node Exporter** (Port 9100) - System metrics
- **Postgres Exporter** (Port 9187) - Database metrics
- **Health Monitor** (Port 8083) - Service health checks

### Logging Stack
- **Loki** (Port 3100) - Log aggregation
- **Promtail** - Log shipping
- **Grafana Logs** (Port 3002) - Log visualization

### Data Validation
- **Data Validator** - Schema validation and data quality checks
- **Dead Letter Queue** - Storage for failed validations

## 🚀 Quick Start

### 1. Environment Setup

Create a `.env` file in the root directory:

```bash
# Database Configuration
MAIN_DB_USER=postgres
MAIN_DB_PASS=your_secure_password
MAIN_DB_NAME=main_db

HOLDING_DB_USER=postgres
HOLDING_DB_PASS=your_secure_password
HOLDING_DB_NAME=holding_db

# Dead Letter Queue
DLQ_DB_USER=dlq_user
DLQ_DB_PASS=dlq_password
DLQ_DB_NAME=dead_letter_queue

# API Security
API_KEY=your_secure_api_key

# Grafana Passwords
GRAFANA_PASSWORD=admin
GRAFANA_LOGS_PASSWORD=admin
```

### 2. Start All Services

```bash
# Start the entire infrastructure
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### 3. Verify Services

Check that all services are running:

```bash
# Health check all services
curl http://localhost:8083/health

# Check individual services
curl http://localhost:8080/health  # API Receiver
curl http://localhost:8081/metrics # Sync Job metrics
curl http://localhost:8082/health  # Data Validator
```

## 📊 Access Points

### Business Applications
- **Metabase Dashboards**: http://localhost:3000
  - Username: admin@metabase.com
  - Password: (set during first setup)

### Monitoring
- **Grafana Monitoring**: http://localhost:3001
  - Username: admin
  - Password: admin (or your GRAFANA_PASSWORD)

- **Prometheus**: http://localhost:9090

### Logging
- **Grafana Logs**: http://localhost:3002
  - Username: admin
  - Password: admin (or your GRAFANA_LOGS_PASSWORD)

- **Loki**: http://localhost:3100

### API Endpoints
- **API Receiver**: http://localhost:8080
  - POST /ingest - Ingest data
  - GET /health - Health check
  - GET /metrics - Prometheus metrics

- **Data Validator**: http://localhost:8082
  - POST /validate - Validate data
  - GET /dlq/stats - Dead letter queue stats
  - GET /health - Health check
  - GET /metrics - Prometheus metrics

- **Health Monitor**: http://localhost:8083
  - GET /health - Overall system health
  - GET /metrics - Prometheus metrics

## 🔧 Data Flow

1. **Data Ingestion**
   ```
   External API → API Receiver → Holding Database
   ```

2. **Data Validation**
   ```
   Holding Database → Data Validator → Valid Data / Dead Letter Queue
   ```

3. **Data Sync**
   ```
   Valid Data → Sync Job → Main Database
   ```

4. **Visualization**
   ```
   Main Database → Metabase → Business Dashboards
   ```

## 📈 Monitoring & Alerting

### Key Metrics to Monitor

1. **API Performance**
   - Request rate and response times
   - Error rates by endpoint
   - Authentication failures

2. **Data Quality**
   - Validation success/failure rates
   - Dead letter queue size
   - Data quality score

3. **System Health**
   - Database connections
   - Disk space usage
   - Service availability

4. **Business Metrics**
   - Records processed per hour
   - Sync lag time
   - Data freshness

### Alert Rules

The system includes pre-configured alerts for:
- Service downtime
- High error rates
- Database connection issues
- Disk space warnings
- Data validation failures

## 🗂️ Data Validation

### Schema Validation

The data validator enforces:
- **JSON Schema** validation for structure
- **Pydantic** models for data types
- **Business rules** (e.g., total_price = quantity × unit_price)

### Dead Letter Queue

Failed validations are stored in the DLQ with:
- Original data
- Validation errors
- Timestamp
- Retry count

### Data Quality Score

A real-time data quality score (0-100) is calculated based on:
- Validation success rate
- Data completeness
- Schema compliance

## 🔍 Troubleshooting

### Common Issues

1. **Services not starting**
   ```bash
   # Check logs
   docker-compose logs [service-name]
   
   # Restart specific service
   docker-compose restart [service-name]
   ```

2. **Database connection issues**
   ```bash
   # Check database status
   docker-compose exec postgres_main pg_isready
   
   # Check network connectivity
   docker-compose exec api_receiver ping postgres_main
   ```

3. **High memory usage**
   ```bash
   # Check resource usage
   docker stats
   
   # Restart services
   docker-compose restart
   ```

### Log Analysis

Use Grafana Logs to:
- Search for specific errors
- Monitor service performance
- Track data flow issues

### Metrics Analysis

Use Grafana Monitoring to:
- Identify performance bottlenecks
- Monitor data quality trends
- Set up custom dashboards

## 🔒 Security

### Network Security
- All services bind to localhost only
- Internal communication via Docker networks
- No external database exposure

### API Security
- API key authentication required
- Rate limiting (configurable)
- Input validation and sanitization

### Data Security
- Encrypted database connections
- Secure credential management
- Audit logging for all operations

## 📚 Next Steps

1. **Custom Dashboards**: Create business-specific dashboards in Grafana
2. **Alert Channels**: Configure Slack/email notifications
3. **Data Sources**: Add more data sources to the pipeline
4. **Scaling**: Consider horizontal scaling for high-volume scenarios
5. **Backup Strategy**: Implement automated backup and recovery

## 🆘 Support

For issues or questions:
1. Check the logs: `docker-compose logs -f`
2. Verify health: `curl http://localhost:8083/health`
3. Review metrics: http://localhost:3001
4. Check logs: http://localhost:3002
