# Dokploy Production Deployment Guide

This guide optimizes the Analytics Infrastructure for production deployment using [Dokploy](https://docs.dokploy.com/docs/core/applications/going-production).

## 🚀 **Production-Ready Setup**

### **Why This Approach is Production-Ready**

✅ **Uses Docker Hub Images**: All services use official images (no local builds)  
✅ **Zero Downtime**: No server resource consumption during deployment  
✅ **Auto Deploy**: GitHub Actions + Docker Hub webhooks  
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
```

## 🐳 **Step 2: Create Dokploy Application**

### **Application Settings**
- **Name**: `analytics-infrastructure`
- **Source Type**: `Docker Compose`
- **Docker Compose File**: `.docker-compose.prod.yml`
- **Build Path**: `/`

### **Environment Variables**
Add all the variables from Step 1 in the Environment Variables tab.

## 🔄 **Step 3: Setup Auto Deploy with GitHub Actions**

### **GitHub Actions Workflow** (`.github/workflows/dokploy-deploy.yml`)

```yaml
name: Deploy to Dokploy

on:
  push:
    branches: ["main"]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Trigger Dokploy Deployment
        run: |
          curl -X 'POST' \
            'https://your-dokploy-domain.com/api/trpc/application.deploy' \
            -H 'accept: application/json' \
            -H 'x-api-key: ${{ secrets.DOKPLOY_API_KEY }}' \
            -H 'Content-Type: application/json' \
            -d '{
              "json": {
                "applicationId": "${{ secrets.DOKPLOY_APP_ID }}"
              }
            }'
```

### **Required GitHub Secrets**
- `DOKPLOY_API_KEY`: Generate in Dokploy → Settings → API Keys
- `DOKPLOY_APP_ID`: Found in your application settings

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
- ✅ No local builds (saves CPU/RAM)
- ✅ Uses pre-built Docker Hub images
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
- ✅ External Docker images (no local builds)
- ✅ Automated deployments via GitHub Actions
- ✅ Health checks and rollbacks
- ✅ Zero downtime deployments
- ✅ Proper environment variable management

Your analytics infrastructure is now ready for production deployment with Dokploy!
