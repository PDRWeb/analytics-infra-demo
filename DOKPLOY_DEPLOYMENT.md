# Dokploy Production Deployment Guide

This guide will help you deploy the Analytics Infrastructure to production using [Dokploy](https://docs.dokploy.com/docs/core/applications/going-production).

## 🚀 Quick Deploy Options

### **Option 1: Railway (Simplest)**
For the easiest deployment, use Railway with the included `railway.json` and `Dockerfile`:

1. **Connect to Railway**: [railway.app](https://railway.app)
2. **Connect GitHub**: Link your repository
3. **Deploy**: Railway automatically detects `railway.json` and deploys
4. **Access**: Get your public URLs from Railway dashboard

**No configuration needed** - just connect and deploy!

#### Railway Configuration Details

The project includes `railway.json` and `Dockerfile` for Railway deployment:

**railway.json:**
```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile"
  },
  "deploy": {
    "startCommand": "docker-compose up -d",
    "healthcheckPath": "/health",
    "healthcheckTimeout": 100,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

**Dockerfile:**
- Uses `docker/compose:2.20.0` as base image
- Installs required tools (curl, postgresql-client)
- Exposes all necessary ports (3000, 3001, 3002, 8080, 8081, 8082, 8083, 9090, 3100)
- Includes health check on port 8083
- Starts the entire stack with `docker-compose up -d`

#### Railway Deployment Steps

1. **Sign up at Railway**: [railway.app](https://railway.app)
2. **Connect GitHub**: Link your repository
3. **Deploy**: Railway automatically detects the configuration
4. **Set Environment Variables**: Add your database passwords and API keys
5. **Access Services**: Get public URLs from Railway dashboard

#### Railway Environment Variables

Add these in Railway's environment variables section:

```
ENVIRONMENT=production
MAIN_DB_USER=postgres
MAIN_DB_PASS=your_secure_password
MAIN_DB_NAME=main_db
HOLDING_DB_USER=postgres
HOLDING_DB_PASS=your_secure_password
HOLDING_DB_NAME=holding_db
DLQ_DB_USER=dlq_user
DLQ_DB_PASS=dlq_password
DLQ_DB_NAME=dead_letter_queue
API_KEY=your_secure_api_key
GRAFANA_PASSWORD=admin
GRAFANA_LOGS_PASSWORD=admin
```

### **Option 2: Dokploy (Advanced)**
For full control and customization, follow the detailed Dokploy setup below.

## Prerequisites

1. **Dokploy Server**: Running Dokploy instance
2. **Docker Hub Account**: For storing built images
3. **GitHub Repository**: With the code and GitHub Actions enabled
4. **Domain/Subdomain**: For accessing the services

## Setup Steps

### 1. GitHub Secrets Configuration

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

```
DOCKERHUB_USERNAME=your_dockerhub_username
DOCKERHUB_TOKEN=your_dockerhub_token
DOKPLOY_DOMAIN=https://your-dokploy-domain.com
DOKPLOY_API_KEY=your_dokploy_api_key
DOKPLOY_API_RECEIVER_ID=your_api_receiver_app_id
DOKPLOY_DATA_VALIDATOR_ID=your_data_validator_app_id
DOKPLOY_HEALTH_MONITOR_ID=your_health_monitor_app_id
```

### 2. Docker Hub Repository Setup

Create the following repositories in Docker Hub:
- `your-username/analytics-infra-api-receiver`
- `your-username/analytics-infra-data-validator`
- `your-username/analytics-infra-health-monitor`

### 3. Dokploy Applications Setup

#### 3.1 API Receiver Application

1. **Source Type**: Docker
2. **Docker Image**: `your-username/analytics-infra-api-receiver:latest`
3. **Port**: 8080
4. **Environment Variables**:
   ```
   PORT=8080
   ENVIRONMENT=production
   API_KEY=your_secure_api_key
   DB_HOST=postgres_main
   DB_PORT=5432
   DB_USER=postgres
   DB_PASS=your_secure_password
   DB_NAME=holding_db
   ```
5. **Health Check**:
   ```json
   {
     "Test": ["CMD", "curl", "-f", "http://localhost:8080/health"],
     "Interval": 30000000000,
     "Timeout": 10000000000,
     "StartPeriod": 30000000000,
     "Retries": 3
   }
   ```
6. **Update Config**:
   ```json
   {
     "Parallelism": 1,
     "Delay": 10000000000,
     "FailureAction": "rollback",
     "Order": "start-first"
   }
   ```

#### 3.2 Data Validator Application

1. **Source Type**: Docker
2. **Docker Image**: `your-username/analytics-infra-data-validator:latest`
3. **Port**: 8080
4. **Environment Variables**:
   ```
   ENVIRONMENT=production
   DB_HOST=holding_db
   DB_PORT=5432
   DB_USER=postgres
   DB_PASS=your_secure_password
   DB_NAME=holding_db
   DLQ_DB_USER=dlq_user
   DLQ_DB_PASS=dlq_password
   DLQ_DB_NAME=dead_letter_queue
   VALIDATION_INTERVAL=30
   ```
5. **Health Check**: Same as API Receiver
6. **Update Config**: Same as API Receiver

#### 3.3 Health Monitor Application

1. **Source Type**: Docker
2. **Docker Image**: `your-username/analytics-infra-health-monitor:latest`
3. **Port**: 8080
4. **Environment Variables**:
   ```
   ENVIRONMENT=production
   PROMETHEUS_URL=http://prometheus:9090
   API_RECEIVER_URL=http://api_receiver:8080
   METABASE_URL=http://metabase:3000
   HOLDING_DB_USER=postgres
   HOLDING_DB_PASS=your_secure_password
   HOLDING_DB_NAME=holding_db
   MAIN_DB_USER=postgres
   MAIN_DB_PASS=your_secure_password
   MAIN_DB_NAME=main_db
   ```
5. **Health Check**: Same as API Receiver
6. **Update Config**: Same as API Receiver

### 4. Database Services Setup

#### 4.1 Main Database (PostgreSQL)

1. **Source Type**: Docker
2. **Docker Image**: `postgres:15`
3. **Port**: 5432
4. **Environment Variables**:
   ```
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=your_secure_password
   POSTGRES_DB=main_db
   ```
5. **Volumes**: `postgres_main_data:/var/lib/postgresql/data`

#### 4.2 Holding Database (PostgreSQL)

1. **Source Type**: Docker
2. **Docker Image**: `postgres:15`
3. **Port**: 5432
4. **Environment Variables**:
   ```
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=your_secure_password
   POSTGRES_DB=holding_db
   ```
5. **Volumes**: `holding_db_data:/var/lib/postgresql/data`

#### 4.3 Dead Letter Queue (PostgreSQL)

1. **Source Type**: Docker
2. **Docker Image**: `postgres:15`
3. **Port**: 5432
4. **Environment Variables**:
   ```
   POSTGRES_USER=dlq_user
   POSTGRES_PASSWORD=dlq_password
   POSTGRES_DB=dead_letter_queue
   ```
5. **Volumes**: `dlq_data:/var/lib/postgresql/data`

### 5. Monitoring Services Setup

#### 5.1 Prometheus

1. **Source Type**: Docker
2. **Docker Image**: `prom/prometheus:v2.45.0`
3. **Port**: 9090
4. **Volumes**: 
   - `./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml`
   - `prometheus_data:/prometheus`

#### 5.2 Grafana

1. **Source Type**: Docker
2. **Docker Image**: `grafana/grafana:10.0.0`
3. **Port**: 3000
4. **Environment Variables**:
   ```
   GF_SECURITY_ADMIN_PASSWORD=admin
   GF_USERS_ALLOW_SIGN_UP=false
   ```
5. **Volumes**: `grafana_data:/var/lib/grafana`

### 6. Logging Services Setup

#### 6.1 Loki

1. **Source Type**: Docker
2. **Docker Image**: `grafana/loki:2.9.0`
3. **Port**: 3100
4. **Volumes**: 
   - `./logging/loki-config.yml:/etc/loki/local-config.yaml`
   - `loki_data:/loki`

#### 6.2 Grafana Logs

1. **Source Type**: Docker
2. **Docker Image**: `grafana/grafana:10.0.0`
3. **Port**: 3000
4. **Environment Variables**:
   ```
   GF_SECURITY_ADMIN_PASSWORD=admin
   GF_USERS_ALLOW_SIGN_UP=false
   GF_INSTALL_PLUGINS=grafana-piechart-panel
   ```
5. **Volumes**: `grafana_logs_data:/var/lib/grafana`

### 7. Visualization Services Setup

#### 7.1 Metabase

1. **Source Type**: Docker
2. **Docker Image**: `metabase/metabase:latest`
3. **Port**: 3000
4. **Environment Variables**:
   ```
   MB_JETTY_PORT=3000
   MB_DB_TYPE=postgres
   MB_DB_DBNAME=metabase
   MB_DB_PORT=5432
   MB_DB_USER=postgres
   MB_DB_PASS=your_secure_password
   MB_DB_HOST=postgres_main
   ```
5. **Volumes**: `metabase_data:/metabase-data`

## Deployment Process

### 1. Initial Setup

1. **Deploy Database Services First**:
   - Main Database
   - Holding Database
   - Dead Letter Queue

2. **Deploy Monitoring Services**:
   - Prometheus
   - Grafana
   - Node Exporter
   - Postgres Exporter

3. **Deploy Logging Services**:
   - Loki
   - Promtail
   - Grafana Logs

4. **Deploy Application Services**:
   - API Receiver
   - Data Validator
   - Health Monitor

5. **Deploy Visualization Services**:
   - Metabase

### 2. Domain Configuration

Configure domains for each service:

- **API Receiver**: `api.yourdomain.com` → Port 8080
- **Data Validator**: `validator.yourdomain.com` → Port 8080
- **Health Monitor**: `health.yourdomain.com` → Port 8080
- **Metabase**: `analytics.yourdomain.com` → Port 3000
- **Grafana Monitoring**: `monitoring.yourdomain.com` → Port 3000
- **Grafana Logs**: `logs.yourdomain.com` → Port 3000
- **Prometheus**: `metrics.yourdomain.com` → Port 9090

### 3. Auto-Deploy Setup

1. **Enable GitHub Actions**: Push to main branch triggers build
2. **Docker Hub Webhooks**: Configure webhooks for auto-deploy
3. **Health Checks**: Configure rollback on failure

## Production Optimizations

### 1. Resource Limits

Set appropriate resource limits for each service:

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```

### 2. Health Checks

All services include built-in health checks:
- **API Receiver**: `GET /health`
- **Data Validator**: `GET /health`
- **Health Monitor**: `GET /health`

### 3. Monitoring

- **Prometheus**: Metrics collection
- **Grafana**: Dashboards and alerting
- **Health Monitor**: Service health aggregation

### 4. Logging

- **Loki**: Log aggregation
- **Promtail**: Log shipping
- **Grafana Logs**: Log visualization

## Troubleshooting

### 1. Service Health Issues

Check service health:
```bash
curl https://api.yourdomain.com/health
curl https://validator.yourdomain.com/health
curl https://health.yourdomain.com/health
```

### 2. Database Connection Issues

Verify database connectivity:
```bash
# Check main database
docker exec -it postgres_main pg_isready -U postgres -d main_db

# Check holding database
docker exec -it holding_db pg_isready -U postgres -d holding_db
```

### 3. Monitoring Issues

Check Prometheus targets:
- Visit `https://metrics.yourdomain.com/targets`
- Verify all services are up

### 4. Log Analysis

Check logs in Grafana Logs:
- Visit `https://logs.yourdomain.com`
- Search for specific errors or issues

## Security Considerations

1. **API Keys**: Use strong, unique API keys
2. **Database Passwords**: Use complex passwords
3. **Network Security**: Configure proper firewall rules
4. **SSL/TLS**: Enable HTTPS for all services
5. **Access Control**: Limit access to monitoring interfaces

## Backup Strategy

1. **Database Backups**: Regular PostgreSQL backups
2. **Configuration Backups**: Backup Docker Compose files
3. **Volume Backups**: Backup persistent volumes
4. **Monitoring Data**: Configure retention policies

## Scaling Considerations

1. **Horizontal Scaling**: Add more API receiver instances
2. **Database Scaling**: Consider read replicas
3. **Monitoring Scaling**: Add more Prometheus instances
4. **Load Balancing**: Use external load balancer

## Support

For issues or questions:
1. Check the logs in Grafana Logs
2. Verify health endpoints
3. Review Prometheus metrics
4. Check Dokploy application logs
