# Infrastructure Monitoring

This directory contains comprehensive monitoring setup for the analytics infrastructure using Prometheus and Grafana, deployed in production via **Dokploy**.

## Overview

The monitoring stack provides:

- **System Resource Monitoring**: CPU, memory, disk, network usage
- **Container Monitoring**: Docker container resource usage and health
- **Database Monitoring**: PostgreSQL performance and connection metrics
- **Service Health Monitoring**: Application service availability and performance
- **Alerting**: Proactive alerts for resource thresholds and service issues
- **Log Aggregation**: Centralized logging with Loki and Grafana

## Components

### Prometheus
- **Port**: 9090
- **Purpose**: Metrics collection and storage
- **Configuration**: `prometheus.yml`
- **Alert Rules**: `alert_rules.yml`
- **Image**: `prom/prometheus:v2.45.0`

### Grafana (Monitoring)
- **Port**: 3001
- **Purpose**: Monitoring dashboards and visualization
- **Default Login**: admin / (set via `GRAFANA_PASSWORD`)
- **Dashboards**: Auto-provisioned from `grafana/dashboards/`
- **Image**: `grafana/grafana:10.0.0`

### Grafana Logs
- **Port**: 3002
- **Purpose**: Log analysis and visualization
- **Default Login**: admin / (set via `GRAFANA_LOGS_PASSWORD`)
- **Image**: `grafana/grafana:10.0.0`

### Loki
- **Port**: 3100
- **Purpose**: Log aggregation and storage
- **Image**: `grafana/loki:2.9.0`

### Promtail
- **Purpose**: Log collection and forwarding to Loki
- **Image**: `grafana/promtail:2.9.0`

### Node Exporter
- **Port**: 9100
- **Purpose**: System metrics collection
- **Metrics**: CPU, memory, disk, network, load average
- **Image**: `prom/node-exporter:v1.6.0`

### Postgres Exporter
- **Port**: 9187
- **Purpose**: PostgreSQL database metrics
- **Metrics**: Connections, database size, query performance
- **Image**: `prometheuscommunity/postgres-exporter:v0.13.2`

### Health Monitor
- **Port**: 8083
- **Purpose**: Custom application health checks
- **Metrics**: Service availability and performance
- **Image**: `${DOCKERHUB_USERNAME}/analytics-infra-health-monitor:latest`

## Dashboards

### 1. Infrastructure Resource Metrics
**File**: `grafana/dashboards/infrastructure-resources.json`

**Key Metrics**:
- System CPU usage percentage
- Memory usage percentage
- Disk usage (root and Docker)
- Network I/O rates
- Load average (1m, 5m, 15m)
- PostgreSQL connections and database size
- Container resource usage
- Service health status

**Use Cases**:
- Monitor overall system health
- Identify resource bottlenecks
- Track capacity planning trends
- Verify service availability

### 2. Docker Infrastructure Monitoring
**File**: `grafana/dashboards/docker-infrastructure.json`

**Key Metrics**:
- Container status overview
- Container CPU usage
- Container memory usage and percentage
- Container network I/O
- Container restart frequency
- Docker volume usage
- Service health checks

**Use Cases**:
- Monitor individual container performance
- Identify problematic containers
- Track resource usage per service
- Debug container issues

## Alerting

### Alert Categories

#### 1. Data Pipeline Alerts
- Database connectivity issues
- API service availability
- Sync job failures
- Metabase service status
- High database connections
- Disk space warnings

#### 2. Resource Alerts
- High CPU usage (80% warning, 95% critical)
- High memory usage (85% warning, 95% critical)
- High load average (>4)
- Container resource thresholds
- Container restart frequency
- Database size growth

#### 3. Service Health Alerts
- Prometheus service status
- Grafana service status
- Node Exporter status
- Health Monitor status

### Alert Severity Levels
- **Critical**: Immediate attention required (service down, very high resource usage)
- **Warning**: Attention needed soon (high resource usage, service degradation)
- **Info**: Informational (database growth, capacity planning)

## Production Deployment with Dokploy

### Prerequisites
1. **Dokploy Server**: Running and accessible
2. **Docker Hub Account**: For custom application images
3. **GitHub Repository**: With automated CI/CD configured
4. **Domain**: Configured in Dokploy for each service

### Environment Variables

Set these in your Dokploy application environment:

```bash
# Database Configuration
MAIN_DB_USER=analytics_user
MAIN_DB_PASS=your_secure_password
MAIN_DB_NAME=analytics_db

HOLDING_DB_USER=holding_user
HOLDING_DB_PASS=your_secure_password
HOLDING_DB_NAME=holding_db

DLQ_DB_USER=dlq_user
DLQ_DB_PASS=your_secure_password
DLQ_DB_NAME=dead_letter_queue

# Monitoring Configuration
GRAFANA_PASSWORD=your_secure_grafana_password
GRAFANA_LOGS_PASSWORD=your_secure_grafana_logs_password

# Application Configuration
DOCKERHUB_USERNAME=your_dockerhub_username
API_KEY=your_secure_api_key
METABASE_APP_DB_NAME=metabase
VALIDATION_INTERVAL=30
```

### Deployment Setup

1. **Create Dokploy Application**:
   - Name: `analytics-infrastructure`
   - Source Type: `Docker Compose`
   - Docker Compose File: `docker-compose.prod.yml`

2. **Configure GitHub Actions**:
   - Set up automated building and pushing of custom images
   - Configure Dokploy deployment triggers
   - See [DOKPLOY_PRODUCTION_GUIDE.md](../DOKPLOY_PRODUCTION_GUIDE.md) for details

3. **Configure Domains**:
   - Grafana Monitoring: Port 3001
   - Grafana Logs: Port 3002
   - Prometheus: Port 9090
   - Loki: Port 3100
   - Health Monitor: Port 8083

### Access Production Services

Replace `your-domain.com` with your actual Dokploy domain:

- **Grafana Monitoring**: https://your-domain.com:3001
  - Username: `admin`
  - Password: `${GRAFANA_PASSWORD}`

- **Grafana Logs**: https://your-domain.com:3002
  - Username: `admin`
  - Password: `${GRAFANA_LOGS_PASSWORD}`

- **Prometheus**: https://your-domain.com:9090

- **Health Monitor**: https://your-domain.com:8083

### View Dashboards

1. Open Grafana Monitoring
2. Navigate to "Dashboards" in the left menu
3. Select from available dashboards:
   - Infrastructure Resource Metrics
   - Docker Infrastructure Monitoring
   - System Health Simple
   - Database Monitoring Simple

## Configuration

### Customizing Dashboards

1. Edit JSON files in `grafana/dashboards/`
2. Commit changes to Git
3. Push to trigger automated deployment
4. Changes will be automatically loaded on next deployment

### Adding Custom Metrics

1. Add scrape config to `prometheus.yml`
2. Create new dashboard or add panels to existing ones
3. Update alert rules in `alert_rules.yml` if needed
4. Deploy via Git push

## Troubleshooting

### Common Issues

#### 1. Dashboards Not Loading

```bash
# Check Grafana logs in Dokploy dashboard
# Or via Dokploy CLI if available

# Verify dashboard files exist in repository
ls -la grafana/dashboards/

# Check file permissions in repository
chmod 644 grafana/dashboards/*.json
```

#### 2. No Data in Dashboards

```bash
# Check Prometheus targets
curl https://your-domain.com:9090/api/v1/targets

# Check alert rules are loaded
curl https://your-domain.com:9090/api/v1/rules
```

#### 3. Service Health Issues

- Check Dokploy application logs for specific services
- Verify environment variables are set correctly
- Check service dependencies are running
- Review health check configurations

### Useful Commands

```bash
# View all metrics
curl https://your-domain.com:9090/api/v1/label/__name__/values

# Check specific metric
curl https://your-domain.com:9090/api/v1/query?query=up

# Test alert rule
curl "https://your-domain.com:9090/api/v1/query?query=up{job=\"api-receiver\"} == 0"

# View Prometheus targets with health status
curl https://your-domain.com:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

## Best Practices

### 1. Dashboard Usage

- **Infrastructure Resource Metrics**: Use for overall system monitoring
- **Docker Infrastructure Monitoring**: Use for container-specific debugging
- Set up time ranges appropriate for your use case (1h for real-time, 24h for trends)

### 2. Alerting

- Start with conservative thresholds
- Adjust based on your system's normal behavior
- Test alerts by temporarily lowering thresholds
- Set up notification channels (email, Slack, etc.) in Grafana

### 3. Maintenance

- Monitor disk usage for Prometheus data via dashboards
- Review and clean up old metrics if needed via retention policies
- Update dashboard configurations as services change
- Regularly review alert effectiveness

### 4. Production Operations

- Use Dokploy's rollback feature if deployments fail
- Monitor deployment logs during updates
- Test monitoring stack after infrastructure changes
- Keep dashboard configurations in Git for version control

## Integration

### With Main Stack

The monitoring stack integrates with the main analytics infrastructure:

- Monitors all application services (API Receiver, Sync Job, Data Validator, Health Monitor)
- Tracks database performance (Main DB, Holding DB, DLQ DB)
- Provides health checks for the entire stack
- Aggregates logs from all services

### With External Tools

- **Slack**: Configure webhook for alert notifications in Grafana
- **Email**: Set up SMTP for email alerts in Grafana
- **PagerDuty**: Integrate for critical alert escalation
- **External Monitoring**: Export metrics to external systems if needed

## Support

For issues or questions:

1. **Check Dokploy Dashboard**: Review application logs and status
2. **Check Service Health**: Use Health Monitor endpoint
3. **Review Metrics**: Use Prometheus query interface
4. **Test Connectivity**: Verify all service endpoints are accessible
5. **Documentation**: [Prometheus](https://prometheus.io/docs/), [Grafana](https://grafana.com/docs/), [Dokploy](https://docs.dokploy.com/)

## Monitoring Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Production Monitoring                │
├─────────────────────────────────────────────────────────┤
│  Grafana (3001) ←── Prometheus (9090) ←── Exporters     │
│  Grafana Logs (3002) ←── Loki (3100) ←── Promtail      │
│  Health Monitor (8083) ←── All Services                 │
├─────────────────────────────────────────────────────────┤
│                      Application Stack                  │
│  API Receiver → Sync Job → Data Validator               │
│  ↓                                                      │
│  Databases (Main, Holding, DLQ) → Metabase (3000)      │
└─────────────────────────────────────────────────────────┘
```

All services are deployed and managed through **Dokploy** with automated CI/CD from GitHub Actions.