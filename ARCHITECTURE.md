# Architecture & Setup Overview

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Infrastructure                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Remote Servers (EC2, VPS, Local Machines)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Server 1     │  │ Server 2     │  │ Server 3     │       │
│  │              │  │              │  │              │       │
│  │ Promtail     │  │ Promtail     │  │ Promtail     │       │
│  │ Node Exp.    │  │ Node Exp.    │  │ Node Exp.    │       │
│  │              │  │              │  │              │       │
│  │ Logs & Metr. │  │ Logs & Metr. │  │ Logs & Metr. │       │
│  └──────┬────────┘  └──────┬────────┘  └──────┬────────┘    │
│         │                 │                 │               │
└─────────┼─────────────────┼─────────────────┼───────────────┘
          │                 │                 │
          └─────────────────┼─────────────────┘
                            │
                            ↓
        ┌───────────────────────────────────────────┐
        │   Central Monitoring Stack (Docker/K8s)   │
        ├───────────────────────────────────────────┤
        │                                            │
        │  ┌─────────────┐  ┌──────────────────┐   │
        │  │  Loki       │  │  Prometheus      │   │
        │  │  (Logs)     │  │  (Metrics)       │   │
        │  │             │  │                  │   │
        │  │ Port: 3100  │  │ Port: 9090       │   │
        │  └────────┬────┘  └────────┬─────────┘   │
        │           │                │              │
        │           └────────┬───────┘              │
        │                    │                      │
        │           ┌────────▼──────────┐           │
        │           │     Grafana       │           │
        │           │                   │           │
        │           │ Dashboard & UI    │           │
        │           │ Port: 3000        │           │
        │           └───────────────────┘           │
        │                                            │
        └───────────────────────────────────────────┘
                            ↑
                    You Access Here
                  http://localhost:3000
```

---

## 📊 Data Flow

```
APPLICATION LOGS          SYSTEM METRICS
│                         │
├─ PM2 logs              ├─ CPU usage
├─ Docker logs           ├─ Memory usage
├─ Syslog                ├─ Disk usage
└─ Custom logs           ├─ Network I/O
                         └─ Process stats
     │                         │
     ▼                         ▼
PROMTAIL                    NODE-EXPORTER
(Log Collector)             (Metric Collector)
     │                         │
     └─────────────┬───────────┘
                   │
                   ▼
          LOKI              PROMETHEUS
          (Logs Storage)    (Metrics Storage)
                   │
                   ▼
              GRAFANA
          (Visualization)
                   │
                   ▼
             YOU SEE DATA
          (Beautiful Dashboards)
```

---

## 🔄 Data Collection Methods

### From Remote Servers

#### Method 1: Using Promtail (Recommended)
- Endpoint: http://remote-server:9080
- Collects logs from files
- Sends to Loki
- Beginner-friendly
- Light on resources

#### Method 2: Using Node Exporter
- Endpoint: http://remote-server:9100
- Collects system metrics
- Scraped by Prometheus
- Lightweight agent
- Works on any OS

### Supported Log Sources

```
Promtail collects from:
│
├─ PM2 Logs
│  └─ Location: ~/.pm2/logs/*.log
│
├─ Docker Logs
│  └─ Location: /var/lib/docker/containers/*/*log
│
├─ System Logs (Syslog)
│  └─ Location: /var/log/syslog
│
└─ Application Logs
   └─ Location: /var/log/app/*.log (configurable)
```

---

## 🚀 Deployment Architectures

### Option 1: Docker Compose (Local/Simple)

```
Single Machine
│
├─ Docker Engine
│  ├─ Loki Container
│  ├─ Grafana Container
│  ├─ Prometheus Container
│  └─ Node Exporter Container
│
└─ Access: http://localhost:3000
```

**Best for:** Development, testing, small projects

### Option 2: Kubernetes (Production-Ready)

```
Kubernetes Cluster
│
├─ monitoring namespace
│  │
│  ├─ loki-pod
│  │  ├─ ConfigMap (config)
│  │  ├─ PersistentVolumeClaim (storage)
│  │  └─ Service: ClusterIP
│  │
│  ├─ prometheus-pod
│  │  ├─ ConfigMap (config)
│  │  ├─ PersistentVolumeClaim (storage)
│  │  ├─ Service: NodePort (30310)
│  │  └─ ServiceAccount & RBAC
│  │
│  └─ grafana-pod
│     ├─ ConfigMap (datasources, dashboards)
│     ├─ PersistentVolumeClaim (storage)
│     └─ Service: NodePort (30300)
│
└─ Access: http://localhost:30300
```

**Best for:** Production, high availability, multiple servers

### Option 3: Distributed Multi-Server

```
Multiple Servers with Central Monitoring

Server 1 (Central)
├─ Grafana (port 3000)
├─ Loki (port 3100)
└─ Prometheus (port 9090)

Server 2 (Remote)
├─ Promtail (9080)
├─ Node Exporter (9100)
└─ Your Applications

Server 3 (Remote)
├─ Promtail (9080)
├─ Node Exporter (9100)
└─ Your Applications

Server 4 (Remote)
├─ Promtail (9080)
├─ Node Exporter (9100)
└─ Your Applications
```

**Best for:** Multi-datacenter, distributed applications

---

## 📋 Configuration Summary

### .env Variables Explained

```env
# Grafana Settings
GRAFANA_ADMIN_USER=admin              # Username (change in production!)
GRAFANA_ADMIN_PASSWORD=admin123       # Password (change in production!)
GRAFANA_PORT=3000                     # Local port

# Loki Settings
LOKI_PORT=3100                        # Local port
LOKI_RETENTION_HOURS=168              # Keep logs for 7 days

# Prometheus Settings
PROMETHEUS_PORT=9090                  # Local port
SCRAPE_INTERVAL=15s                   # How often to collect metrics

# Remote Servers
REMOTE_SERVER_1_NAME=ec2-server-1     # Display name
REMOTE_SERVER_1_HOST=10.0.1.100       # IP address
REMOTE_SERVER_1_PORT=9100             # Node Exporter port

# Kubernetes (if using K8s)
NAMESPACE=monitoring                  # K8s namespace
GRAFANA_NODE_PORT=30300              # K8s port (external)
LOKI_NODE_PORT=30310                 # K8s port (external)
```

---

## 🔌 Service Ports

### Local Machine Access (Docker Compose)

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| Grafana | 3000 | http://localhost:3000 | Dashboards |
| Loki | 3100 | http://localhost:3100 | Logs API |
| Prometheus | 9090 | http://localhost:9090 | Metrics API |
| Node Exporter | 9100 | http://localhost:9100 | Local metrics |

### Remote Server Access

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| Node Exporter | 9100 | http://server:9100/metrics | Metrics scraping |
| Promtail | 9080 | http://server:9080 | Status only |

### Kubernetes (NodePort) Access

| Service | Node Port | URL | Purpose |
|---------|-----------|-----|---------|
| Grafana | 30300 | http://localhost:30300 | Dashboards |
| Prometheus | 30310 | http://localhost:30310 | Metrics |

---

## 📦 Container Images Used

```yaml
# Official images used
services:
  loki:
    image: grafana/loki:latest
    # Size: ~50-100MB
    # Memory: 256-512MB

  grafana:
    image: grafana/grafana:latest
    # Size: ~100-150MB
    # Memory: 128-512MB

  prometheus:
    image: prom/prometheus:latest
    # Size: ~100-150MB
    # Memory: 256-1GB

  node-exporter:
    image: prom/node-exporter:latest
    # Size: ~20-30MB
    # Memory: 50-100MB
```

---

## 🔄 Message Flow Examples

### Example 1: PM2 Application Crashes
```
1. PM2 writes error to log file
   └─ /home/user/.pm2/logs/app-error.log

2. Promtail detects new log entry
   └─ Reads: "Error: Connection timeout"

3. Promtail sends to Loki
   └─ HTTP POST to http://LOKI_IP:3100/loki/api/v1/push

4. Loki stores the log
   └─ Database: /loki/chunks/

5. Grafana displays it
   └─ Query: {job="pm2"} |= "Connection timeout"

6. You see it in Grafana dashboard
   └─ In the "Application Logs" section
```

### Example 2: Server CPU Spikes
```
1. Node Exporter collects CPU metrics
   └─ Every 15 seconds

2. Prometheus scrapes metrics
   └─ Visits http://SERVER:9100/metrics

3. Prometheus stores metrics
   └─ Database: /prometheus/tsdb/

4. Grafana retrieves metrics
   └─ Query: rate(node_cpu_seconds_total[5m])

5. Grafana displays graph
   └─ In the "System Monitoring Dashboard"

6. You see CPU spike in real-time
   └─ You can click to see which process caused it
```

---

## 📈 Typical Setup Timeline

```
0 min:   Start here with Docker Compose
5 min:   Services are running
10 min:  Access Grafana, see local metrics
20 min:  Setup first remote server
30 min:  See metrics from remote server
45 min:  Configure custom dashboards
60 min:  Everything running smoothly!
```

---

## 🎯 Next Steps After Setup

1. **Test Locally** (Docker Compose)
   - Deploy and access Grafana
   - Create test queries
   - Understand the interface

2. **Add First Remote Server**
   - Run setup script on remote server
   - Update .env on central server
   - Verify metrics appear

3. **Customize**
   - Edit log paths for your apps
   - Create custom dashboards
   - Setup alerts

4. **Scale Up**
   - Add more remote servers using same script
   - Consider Kubernetes for high availability
   - Setup backups and retention policies

---

**Ready to deploy? Check README.md or QUICK_START.md!** 🚀
