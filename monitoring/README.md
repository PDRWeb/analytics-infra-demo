# Infrastructure Monitoring

This directory contains comprehensive monitoring setup for the analytics infrastructure using Prometheus and Grafana.

## Overview

The monitoring stack provides:

- **System Resource Monitoring**: CPU, memory, disk, network usage
- **Container Monitoring**: Docker container resource usage and health
- **Database Monitoring**: PostgreSQL performance and connection metrics
- **Service Health Monitoring**: Application service availability and performance
- **Alerting**: Proactive alerts for resource thresholds and service issues

## Components

### Prometheus

- **Port**: 9090
- **Purpose**: Metrics collection and storage
- **Configuration**: `prometheus.yml`
- **Alert Rules**: `alert_rules.yml`

### Grafana

- **Port**: 3001
- **Purpose**: Visualization and dashboards
- **Default Login**: admin/admin
- **Dashboards**: Auto-provisioned from `grafana/dashboards/`

### Node Exporter

- **Port**: 9100
- **Purpose**: System metrics collection
- **Metrics**: CPU, memory, disk, network, load average

### Postgres Exporter

- **Port**: 9187
- **Purpose**: PostgreSQL database metrics
- **Metrics**: Connections, database size, query performance

### Health Monitor

- **Port**: 8083
- **Purpose**: Custom application health checks
- **Metrics**: Service availability and performance

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

## Quick Start

### 1. Start Monitoring Stack

```bash
# Start monitoring services
cd monitoring
docker-compose up -d

# Check status
docker-compose ps
```

### 2. Access Dashboards

- **Grafana**: [http://localhost:3001](http://localhost:3001)
  - Username: `admin`
  - Password: `admin` (or your GRAFANA_PASSWORD)
- **Prometheus**: [http://localhost:9090](http://localhost:9090)

### 3. View Dashboards

1. Open Grafana
2. Navigate to "Dashboards" in the left menu
3. Select "Infrastructure Resource Metrics" or "Docker Infrastructure Monitoring"

## Configuration

### Environment Variables

Set these in your `.env` file:

```bash
GRAFANA_PASSWORD=your_secure_password
MAIN_DB_USER=postgres
MAIN_DB_PASS=your_secure_password
MAIN_DB_NAME=main_db
```

### Customizing Dashboards

1. Edit JSON files in `grafana/dashboards/`
2. Restart Grafana: `docker-compose restart grafana`
3. Changes will be automatically loaded

### Adding Custom Metrics

1. Add scrape config to `prometheus.yml`
2. Create new dashboard or add panels to existing ones
3. Update alert rules in `alert_rules.yml` if needed

## Troubleshooting

### Common Issues

#### 1. Dashboards Not Loading

```bash
# Check Grafana logs
docker-compose logs grafana

# Verify dashboard files exist
ls -la grafana/dashboards/

# Check file permissions
chmod 644 grafana/dashboards/*.json
```

#### 2. No Data in Dashboards

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check if exporters are running
docker-compose ps | grep exporter

# Check Prometheus logs
docker-compose logs prometheus
```

#### 3. Alerts Not Firing

```bash
# Check alert rules are loaded
curl http://localhost:9090/api/v1/rules

# Check Prometheus configuration
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

### Useful Commands

```bash
# View all metrics
curl http://localhost:9090/api/v1/label/__name__/values

# Check specific metric
curl http://localhost:9090/api/v1/query?query=up

# Test alert rule
curl http://localhost:9090/api/v1/query?query=up{job="api-receiver"} == 0

# View Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
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
- Set up notification channels (email, Slack, etc.)

### 3. Maintenance

- Monitor disk usage for Prometheus data
- Review and clean up old metrics if needed
- Update dashboard configurations as services change
- Regularly review alert effectiveness

## Integration

### With Main Stack

The monitoring stack integrates with the main analytics infrastructure:

- Monitors all application services
- Tracks database performance
- Provides health checks for the entire stack

### With External Tools

- **Slack**: Configure webhook for alert notifications
- **Email**: Set up SMTP for email alerts
- **PagerDuty**: Integrate for critical alert escalation

## Support

For issues or questions:

1. Check logs: `docker-compose logs -f`
2. Verify configuration: `docker-compose config`
3. Test connectivity: `curl http://localhost:9090/api/v1/targets`
4. Review documentation: [Prometheus](https://prometheus.io/docs/), [Grafana](https://grafana.com/docs/)
