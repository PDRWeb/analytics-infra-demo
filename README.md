# Analytics Infra Demo 🚀

This repository demonstrates a **containerized analytics infrastructure** suitable for small businesses or personal projects.  
It uses **Docker**, **Postgres**, and **Metabase** to create a secure, automated data pipeline.

## 🌐 High-Level Architecture

![Architecture Diagram](docs/architecture.png)

**Flow**:

1. **n8n Cloud** sends API data → Container-1 (API Receiver).
2. Container-1 stores in **holding Postgres** and syncs to main DB.
3. **Container-2 (Synology/Postgres)** holds the authoritative dataset.
4. **Container-3 (Metabase)** connects to the main DB → dashboards for business users.

---

## 📦 Project Structure

- `ingestion/` → Container-1 (API Receiver + Holding DB + Sync jobs).
- `database/` → Container-2 (Main Postgres + Backups + Restore tests).
- `visualization/` → Container-3 (Metabase dashboards).
- `docs/` → Architecture diagram & security notes.

---

## 🔐 Security Principles

- ✅ No direct Postgres exposure on the internet.  
- ✅ HTTPS via Cloudflare Tunnel for incoming API traffic.  
- ✅ Tailscale for private networking (Mac ↔ Synology).  
- ✅ Strong API keys and `.env` secrets.  
- ✅ Automated backups with restore verification.  

See [docs/SECURITY.md](docs/SECURITY.md).

---

## 🚀 Getting Started

Clone the repo:

```bash
git clone https://github.com/PDRWeb/analytics-infra-demo.git
cd analytics-infra-demo
```

### Quick Start

1. **Setup Environment**:

   ```bash
   cp env.example .env
   # Edit .env with your secure passwords and API keys
   ```

2. **Start the Stack**:

   ```bash
   ./manage-stack.sh start
   ```

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
