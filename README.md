# Analytics Infra Demo

This repository demonstrates a **containerized analytics infrastructure** suitable for small businesses or personal projects.  
It uses **Docker**, **Postgres**, and **Metabase** to create a secure, automated data pipeline.

## Table of Contents

- [High-Level Architecture](#high-level-architecture)
- [Project Structure](#project-structure)
- [Security Principles](#security-principles)
- [Getting Started](#getting-started)
  - [Quick Start](#quick-start)
  - [Management Commands](#management-commands)
- [Production Deployment](#production-deployment)
  - [Dokploy Deployment](#dokploy-deployment)
  - [CI/CD Pipeline](#cicd-pipeline)

## High-Level Architecture

![Architecture Diagram](docs/architecture.png)

**Flow**:

1. **n8n Cloud** sends API data → Container-1 (API Receiver).
2. **Container-1** stores in **holding Postgres** and syncs to main DB.
3. **Container-2 (Postgres)** holds the authoritative dataset.
4. **Container-3 (Metabase)** connects to the main DB → dashboards for business users.

---

## Project Structure

- `ingestion/` → Container-1 (API Receiver + Holding DB + Sync jobs).
- `database/` → Container-2 (Main Postgres + Backups + Restore tests).
- `visualization/` → Container-3 (Metabase dashboards).
- `docs/` → Architecture diagram & security notes.

---

## Security Principles

- No direct Postgres exposure on the internet.  
- HTTPS via Cloudflare Tunnel for incoming API traffic.  
- Tailscale for private networking (Host1 ↔ Host2).  
- Strong API keys and `.env` secrets.  
- Automated backups with restore verification.  

See [docs/SECURITY.md](docs/SECURITY.md).

---

## Getting Started

Clone the repo:

```bash
git clone https://github.com/PDRWeb/analytics-infra-demo.git
cd analytics-infra-demo
```

### Quick Start

1. **Setup Environment**:

   ```bash
   cp .env.example .env
   # Edit .env with your secure passwords and API keys
   ```

2. **Start the Stack**:

   ```bash
   ./manage-stack.sh start
   ```

   The script will start all services and then ask if you want to generate demo data:
   - **Yes (y)**: Creates database schema + generates fresh demo data
   - **No (n)**: Starts with empty database (for production use)

3. **Check Status**:

   ```bash
   ./manage-stack.sh status
   ```

4. **Access Dashboards**:

   - Metabase: [http://localhost:3000](http://localhost:3000)
   - Grafana Monitoring: [http://localhost:3001](http://localhost:3001)
   - Grafana Logs: [http://localhost:3002](http://localhost:3002)

### Management Commands

```bash
./manage-stack.sh start     # Start entire stack
./manage-stack.sh stop      # Stop all services
./manage-stack.sh restart   # Restart stack
./manage-stack.sh status    # Check health
./manage-stack.sh logs      # View logs
./manage-stack.sh clean     # Remove everything
./manage-stack.sh help      # Show all commands
```

---

## Production Deployment

### Dokploy Deployment

This project is optimized for production deployment using [Dokploy](https://docs.dokploy.com/docs/core/applications/going-production), following the recommended CI/CD pipeline approach to avoid resource-intensive builds on the server.

#### Key Features

- **Multi-stage Docker builds** for optimized production images
- **GitHub Actions CI/CD** for automated building and deployment
- **Health checks and rollbacks** for zero-downtime deployments
- **Production-ready security** with non-root users and proper permissions
- **Comprehensive monitoring** with Prometheus, Grafana, and Loki

#### Quick Start

1. **Configure GitHub Secrets**:
   ```
   DOCKERHUB_USERNAME=your_dockerhub_username
   DOCKERHUB_TOKEN=your_dockerhub_token
   DOKPLOY_DOMAIN=https://your-dokploy-domain.com
   DOKPLOY_API_KEY=your_dokploy_api_key
   ```

2. **Create Docker Hub Repositories**:
   - `your-username/analytics-infra-api-receiver`
   - `your-username/analytics-infra-data-validator`
   - `your-username/analytics-infra-health-monitor`

3. **Deploy to Dokploy**:
   - Follow the detailed guide in [DOKPLOY_DEPLOYMENT.md](DOKPLOY_DEPLOYMENT.md)
   - Use the production docker-compose: `docker-compose.prod.yml`
   - Configure domains and environment variables

#### Production Architecture

```
GitHub → GitHub Actions → Docker Hub → Dokploy → Production
   ↓           ↓              ↓           ↓
  Code    Build Images    Store Images  Deploy Apps
```

### CI/CD Pipeline

The project includes automated CI/CD pipelines:

- **`.github/workflows/deploy.yml`**: Builds and pushes Docker images
- **`.github/workflows/init-db.yml`**: Database initialization workflow
- **Multi-platform builds**: Supports both AMD64 and ARM64 architectures
- **Automated deployments**: Triggers Dokploy deployments on successful builds

#### Build Types

- **Dockerfile**: Multi-stage builds for production optimization
- **Docker Context**: Service-specific contexts for efficient builds
- **Build Stages**: Dependencies → Production stages for security and size optimization

#### Production Optimizations

- **Non-root users**: All containers run as non-root for security
- **Health checks**: Built-in health monitoring for all services
- **Resource limits**: Configurable CPU and memory limits
- **Rollback support**: Automatic rollback on health check failures
- **Zero-downtime**: Rolling updates with health verification

For detailed deployment instructions, see [DOKPLOY_DEPLOYMENT.md](DOKPLOY_DEPLOYMENT.md).
