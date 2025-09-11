# Dokploy Production Deployment Guide

This guide optimizes the Analytics Infrastructure for production deployment using [Dokploy](https://docs.dokploy.com/docs/core/applications/going-production).

## 🚀 **Production-Ready Setup**

### **Why This Approach is Production-Ready**

✅ **Hybrid Approach**: Infrastructure services use official images, application services use custom builds  
✅ **Zero Downtime**: No server resource consumption during deployment  
✅ **Auto Deploy**: GitHub Actions builds and pushes to Docker Hub, then triggers Dokploy  
✅ **Health Checks**: Built-in container health monitoring  
✅ **Rollbacks**: Automatic rollback on health check failures  

## 📋 **Prerequisites**

1. **Dokploy Server**: Running and accessible
2. **Docker Hub Account**: For image registry
3. **GitHub Repository**: With your code
4. **Domain**: For external access (optional)

## 🔧 **Step 1: Configure Environment Variables in Dokploy**

### **Database Configuration**
```
MAIN_DB_USER=analytics_user
MAIN_DB_PASS=your_secure_password
MAIN_DB_NAME=analytics_db
MAIN_DB_HOST=postgres_main

HOLDING_DB_USER=holding_user
HOLDING_DB_PASS=your_secure_password
HOLDING_DB_NAME=holding_db
HOLDING_DB_HOST=holding_db

DLQ_DB_USER=dlq_user
DLQ_DB_PASS=your_secure_password
DLQ_DB_NAME=dead_letter_queue
DLQ_DB_HOST=dead_letter_queue
```

### **Monitoring Configuration**
```
GRAFANA_PASSWORD=your_grafana_password
GRAFANA_LOGS_PASSWORD=your_grafana_logs_password
```

### **Application Configuration**
```
API_KEY=your_secure_api_key
METABASE_APP_DB_NAME=metabase
VALIDATION_INTERVAL=30
DOCKERHUB_USERNAME=your_dockerhub_username
```

## 🐳 **Step 2: Create Dokploy Application**

### **Application Settings**
- **Name**: `analytics-infrastructure`
- **Source Type**: `Docker Compose`
- **Docker Compose File**: `docker-compose.prod.yml`
- **Build Path**: `/`

### **Environment Variables**
Add all the variables from Step 1 in the Environment Variables tab.

### **Docker Compose Configuration Details**

The `docker-compose.prod.yml` file contains:

#### **Infrastructure Services (Official Images)**
- **PostgreSQL**: `postgres:15` (3 instances: main, holding, DLQ)
- **Prometheus**: `prom/prometheus:v2.45.0`
- **Grafana**: `grafana/grafana:10.0.0` (2 instances: monitoring + logs)
- **Loki**: `grafana/loki:2.9.0`
- **Promtail**: `grafana/promtail:2.9.0`
- **Metabase**: `metabase/metabase:latest`
- **Node Exporter**: `prom/node-exporter:v1.6.0`
- **Postgres Exporter**: `prometheuscommunity/postgres-exporter:v0.13.2`

#### **Application Services (Custom Images)**
- **API Receiver**: `${DOCKERHUB_USERNAME}/analytics-infra-api-receiver:latest`
- **Sync Job**: `${DOCKERHUB_USERNAME}/analytics-infra-sync-job:latest`
- **Data Validator**: `${DOCKERHUB_USERNAME}/analytics-infra-data-validator:latest`
- **Health Monitor**: `${DOCKERHUB_USERNAME}/analytics-infra-health-monitor:latest`

#### **Key Features**
- **Health Checks**: All services have proper health check configurations
- **Dependencies**: Services start in correct order with proper dependencies
- **Networks**: All services communicate via internal `db_net` network
- **Volumes**: Persistent data storage for databases and monitoring
- **Environment Variables**: All services use environment variables for configuration

### **Detailed Docker Compose Configuration**

#### **Service Dependencies**
```
postgres_main (database)
├── holding_db (holding database)
├── dead-letter-queue (DLQ database)
├── api-receiver (depends on holding_db)
├── sync-job (depends on holding_db + postgres_main)
├── data-validator (depends on holding_db + dead-letter-queue)
├── metabase (depends on postgres_main)
├── prometheus (monitoring)
├── grafana (depends on prometheus)
├── loki (logging)
├── grafana-logs (depends on loki)
└── health-monitor (depends on prometheus)
```

#### **Port Configuration**
- **Internal Services**: sync-job, data-validator (no external ports)
- **External Services**: api-receiver (8080), health-monitor (8083)
- **Web Services**: metabase (3000), grafana (3001), grafana-logs (3002)
- **Infrastructure**: prometheus (9090), loki (3100)

#### **Volume Mounts**
- **Database Data**: `postgres_main_data`, `holding_db_data`, `dlq_data`
- **Monitoring Data**: `prometheus_data`, `grafana_data`, `grafana_logs_data`
- **Logging Data**: `loki_data`
- **Application Data**: `metabase_data`

#### **Health Check Configuration**
Each service has specific health checks:
- **Databases**: `pg_isready` command
- **Web Services**: HTTP health endpoints
- **Monitoring**: Service-specific health checks

## 🔄 **Step 3: Setup Auto Deploy with GitHub Actions**

### **GitHub Actions Workflow** (`.github/workflows/deploy.yml`)

The workflow automatically:
1. **Builds** all 4 application services (api-receiver, sync-job, data-validator, health-monitor)
2. **Pushes** images to Docker Hub as `username/analytics-infra-service:latest`
3. **Triggers** Dokploy deployments for each service

### **Required GitHub Secrets**
- `DOCKERHUB_USERNAME`: Your Docker Hub username
- `DOCKERHUB_TOKEN`: Your Docker Hub access token
- `DOKPLOY_DOMAIN`: Your Dokploy server domain
- `DOKPLOY_API_KEY`: Generate in Dokploy → Settings → API Keys
- `DOKPLOY_API_RECEIVER_ID`: Application ID for API Receiver
- `DOKPLOY_SYNC_JOB_ID`: Application ID for Sync Job
- `DOKPLOY_DATA_VALIDATOR_ID`: Application ID for Data Validator
- `DOKPLOY_HEALTH_MONITOR_ID`: Application ID for Health Monitor

### **How It Works**
1. **Push to main branch** triggers the workflow
2. **GitHub Actions builds** all 4 Docker images in parallel
3. **Images are pushed** to Docker Hub with proper tags
4. **Dokploy deployments** are triggered for each service
5. **Dokploy pulls** the new images and deploys them

## 🌐 **Step 4: Configure Domains and Ports**

### **Service Ports**
- **API Receiver**: Port 8080 (Data Ingestion API)
- **Sync Job**: Internal (Data Synchronization)
- **Data Validator**: Internal (Data Validation)
- **Health Monitor**: Port 8083 (System Health)
- **Metabase**: Port 3000 (Data Visualization)
- **Grafana**: Port 3001 (Monitoring Dashboards)  
- **Grafana Logs**: Port 3002 (Log Analysis)
- **Prometheus**: Port 9090 (Metrics)
- **Loki**: Port 3100 (Logs)

### **Domain Configuration**
1. Go to **Domains** tab in your application
2. Click **Dices** icon to generate domains
3. Configure each service with appropriate port

## 🏥 **Step 5: Configure Health Checks and Rollbacks**

### **Health Check Configuration**
Go to **Advanced** → **Cluster Settings** → **Swarm Settings**

```json
{
  "Test": [
    "CMD",
    "curl",
    "-f",
    "http://localhost:3000/api/health"
  ],
  "Interval": 30000000000,
  "Timeout": 10000000000,
  "StartPeriod": 30000000000,
  "Retries": 3
}
```

### **Rollback Configuration**
```json
{
  "Parallelism": 1,
  "Delay": 10000000000,
  "FailureAction": "rollback",
  "Order": "start-first"
}
```

## 🚀 **Step 6: Deploy**

1. **Initial Deploy**: Click "Deploy" in Dokploy
2. **Auto Deploy**: Push to main branch triggers automatic deployment
3. **Monitor**: Check logs and health status

## 📊 **Production Benefits**

### **Resource Efficiency**
- ✅ Minimal server resource usage (only pulls images)
- ✅ Custom application images built in GitHub Actions
- ✅ Zero downtime deployments

### **Reliability**
- ✅ Automatic rollbacks on failure
- ✅ Health check monitoring
- ✅ Container restart policies

### **Scalability**
- ✅ Easy horizontal scaling
- ✅ Load balancer ready
- ✅ Database connection pooling

## 🔍 **Monitoring and Maintenance**

### **Health Monitoring**
- **Prometheus**: http://your-domain:9090
- **Grafana**: http://your-domain:3001
- **Grafana Logs**: http://your-domain:3002

### **Application Monitoring**
- **Metabase**: http://your-domain:3000
- **Container Logs**: Available in Dokploy dashboard

## 🛠 **Troubleshooting**

### **Common Issues**
1. **Environment Variables**: Ensure all required vars are set in Dokploy
2. **Port Conflicts**: Check that ports are properly exposed
3. **Health Checks**: Verify health check endpoints are responding
4. **Database Connections**: Ensure database containers are healthy

### **Debug Commands**
```bash
# Check container status
docker ps

# View logs
docker logs <container_name>

# Check health
curl http://localhost:3000/api/health
```

## 📈 **Scaling Considerations**

### **Database Scaling**
- Consider external managed databases for production
- Implement connection pooling
- Set up database backups

### **Application Scaling**
- Use load balancers for multiple instances
- Implement horizontal pod autoscaling
- Monitor resource usage

## 🔒 **Security Best Practices**

1. **Environment Variables**: Never commit secrets to repository
2. **Network Security**: Use internal networks for database communication
3. **Access Control**: Implement proper authentication
4. **SSL/TLS**: Use HTTPS for external access
5. **Regular Updates**: Keep Docker images updated

---

## 🎉 **You're Production Ready!**

This setup follows Dokploy's production best practices:
- ✅ Hybrid approach (official + custom images)
- ✅ Automated builds and deployments via GitHub Actions
- ✅ Health checks and rollbacks
- ✅ Zero downtime deployments
- ✅ Proper environment variable management

Your analytics infrastructure is now ready for production deployment with Dokploy!
