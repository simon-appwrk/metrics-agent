# 📊 Grafana + Loki Monitoring Stack - Complete Project

## 🎉 Your monitoring stack is ready!

This folder contains a **production-ready**, **beginner-friendly** monitoring solution for collecting logs and metrics from multiple servers.

---

## 📖 Start Here - Choose Your Documentation

### 🚀 For Quick Setup (5 min)
→ **[GETTING_STARTED.md](GETTING_STARTED.md)** - Step-by-step with Python-like code blocks

### 📚 For Full Documentation
→ **[README.md](README.md)** - Complete guide with troubleshooting

### ⚡ For Quick Reference
→ **[QUICK_START.md](QUICK_START.md)** - Commands and URLs at a glance

### 🏗️ To Understand Architecture
→ **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design and data flow diagrams

### 🪟 For Windows Servers
→ **[WINDOWS_SETUP.md](WINDOWS_SETUP.md)** - Setting up Windows machines as remote servers

---

## 📁 What's Included

### Configuration Files
```
docker-compose.yml              ← Complete Docker setup
loki-config.yml                 ← Log storage configuration
prometheus.yml                  ← Metrics collection targets
.env.example                    ← Environment variables template
.gitignore                      ← Don't commit .env to GitHub!
```

### Deployment Scripts
```
scripts/
├── deploy-docker.sh            ← Linux/Mac Docker deployment
├── deploy-docker.bat           ← Windows Docker deployment
├── deploy-k8s.sh              ← Linux/Mac Kubernetes deployment
├── deploy-k8s.ps1             ← Windows PowerShell Kubernetes deployment
└── setup-remote-server.sh      ← Setup remote servers (EC2, VPS, etc.)
```

### Kubernetes (Optional)
```
kubernetes/
├── loki-deployment.yml         ← Loki with storage and ConfigMap
├── grafana-deployment.yml      ← Grafana with datasources
└── prometheus-deployment.yml   ← Prometheus with RBAC
```

### Log Collection
```
promtail-config/
└── promtail-config.yml         ← Multi-source log collection
```

### Grafana Auto-Setup
```
grafana-provisioning/
├── datasources/
│   └── datasources.yml         ← Auto-adds Loki & Prometheus
└── dashboards/
    └── dashboards.yml          ← Auto-provisions dashboards

grafana-dashboards/
└── system-dashboard.json       ← Pre-built monitoring dashboard
```

### Documentation
```
README.md                       ← Full documentation & troubleshooting
GETTING_STARTED.md             ← Step-by-step setup guide
QUICK_START.md                 ← Quick reference
ARCHITECTURE.md                ← System design diagrams
WINDOWS_SETUP.md               ← Windows server setup
SETUP_COMPLETE.md              ← Welcome & overview
INDEX.md                       ← This file!
```

---

## 🎯 Quick Start (Choose One)

### Option A: Local Testing with Docker
```bash
cp .env.example .env                    # Copy configuration
./scripts/deploy-docker.sh              # Run on Linux/Mac
.\scripts\deploy-docker.bat             # Run on Windows
```
→ Visit: http://localhost:3000

### Option B: Kubernetes Production
```bash
cp .env.example .env                    # Copy configuration
./scripts/deploy-k8s.sh                 # Run on Linux/Mac
.\scripts\deploy-k8s.ps1                # Run on Windows PowerShell
```
→ Visit: http://localhost:30300

---

## 📊 What You Can Monitor

### System Metrics (from remote servers)
- ✅ CPU usage
- ✅ Memory usage
- ✅ Disk space
- ✅ Network traffic
- ✅ Load average
- ✅ Process information
- ✅ File descriptors

### Application Logs (from remote servers)
- ✅ PM2 logs (Node.js apps)
- ✅ Docker logs (containers)
- ✅ Syslog (system events)
- ✅ Custom application logs
- ✅ Windows Event logs (Windows servers)
- ✅ IIS logs (Windows servers)

### Supported Server Types
- ✅ AWS EC2 instances
- ✅ VPS/Cloud servers
- ✅ Local machines on network
- ✅ Windows Server
- ✅ Linux (any distribution)
- ✅ macOS

---

## 🔗 How It Works

```
Your Servers
    ↓ (Promtail sends logs)
    ↓ (Node Exporter sends metrics)
    ↓
Central Monitoring Stack
    ├─ Loki (collects logs)
    ├─ Prometheus (collects metrics)
    ├─ Grafana (shows dashboards)
    ↓
You See Everything!
```

---

## 🌍 Default Ports & Access

| Service | Local Port | Docker URL | K8s NodePort |
|---------|-----------|------------|--------------|
| Grafana | 3000 | http://localhost:3000 | 30300 |
| Prometheus | 9090 | http://localhost:9090 | 30310 |
| Loki | 3100 | http://localhost:3100 | Via Grafana |
| Node Exporter | 9100 | http://localhost:9100 | - |

**Default Login:** admin / admin123

---

## ✨ Key Features

- ✅ **Simple to use** - No complex configuration needed
- ✅ **Easy deployment** - One command per environment
- ✅ **Multi-source** - Collect from 3-4+ servers
- ✅ **Beginner-friendly** - Works for newcomers and experts
- ✅ **Production-ready** - Can handle real workloads
- ✅ **Flexible** - Docker OR Kubernetes
- ✅ **Self-documenting** - Configurations are well-commented
- ✅ **Auto-provisioning** - Datasources and dashboards pre-configured
- ✅ **Secure** - Environment variables, `.gitignore` included
- ✅ **Multi-platform** - Windows, Linux, macOS support

---

## 🎓 Learning Path

### Beginner (Start here)
1. Read [GETTING_STARTED.md](GETTING_STARTED.md)
2. Deploy with Docker
3. View logs in Grafana
4. Explore dashboards

### Intermediate
1. Setup first remote server
2. Add metrics to Grafana
3. Create custom dashboards
4. Learn Loki query language

### Advanced
1. Deploy to Kubernetes
2. Setup multiple remote servers
3. Create alert rules
4. Backups and scaling

---

## 🛠️ Configuration

### Before First Run
1. Copy `.env.example` to `.env`
2. Edit `.env` if you want to change ports/passwords
3. Add remote server IPs (optional)
4. Run deployment script

### To Add Remote Servers
1. Update server IPs in `.env` (optional, or add manually)
2. Copy `setup-remote-server.sh` to remote server
3. Run: `sudo bash setup-remote-server.sh <CENTRAL_IP> <SERVER_NAME>`
4. Restart Prometheus/Grafana
5. Check in Prometheus UI for targets

### To Customize Log Paths
1. SSH to remote server
2. Edit `/etc/promtail/config.yml`
3. Add your log paths
4. Restart: `sudo systemctl restart promtail`

---

## 📚 Documentation Breakdown

| Document | Best For | Read Time |
|----------|----------|-----------|
| GETTING_STARTED.md | Quick setup | 5 min |
| README.md | Complete understanding | 20 min |
| QUICK_START.md | Command reference | 5 min |
| ARCHITECTURE.md | Understanding design | 15 min |
| WINDOWS_SETUP.md | Windows servers | 10 min |
| SETUP_COMPLETE.md | Overview & intro | 10 min |

---

## 🔍 Troubleshooting

### General Issues
→ See **[README.md](README.md)** - "Troubleshooting" section

### Docker Issues
→ Check: `docker-compose logs [service_name]`

### Kubernetes Issues
→ Check: `kubectl logs -n monitoring -l app=[service]`

### Remote Server Issues
→ See **[WINDOWS_SETUP.md](WINDOWS_SETUP.md)** for Windows
→ See **[README.md](README.md)** for Linux

---

## 🚀 Next Steps

### Do This Now
```bash
1. copy .env.example .env
2. Read GETTING_STARTED.md
3. Run deploy script
4. Access http://localhost:3000
5. Explore Grafana!
```

### Do This Next
```bash
1. Setup your first remote server
2. Make custom dashboard
3. Create a few queries
4. Share with your team!
```

---

## 📞 Support Resources

- **[README.md](README.md)** - Most complete documentation
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Understand the system
- **Official Docs:**
  - Grafana: https://grafana.com/docs/
  - Loki: https://grafana.com/docs/loki/
  - Prometheus: https://prometheus.io/docs/
  - Kubernetes: https://kubernetes.io/docs/

---

## 📋 File Checklist

When you first clone/download, you should have:

- [ ] docker-compose.yml
- [ ] loki-config.yml
- [ ] prometheus.yml
- [ ] .env.example
- [ ] .gitignore
- [ ] scripts/ (with 5 shell/batch files)
- [ ] kubernetes/ (with 3 yml files)
- [ ] promtail-config/ (with 1 yml file)
- [ ] grafana-provisioning/ (with 2 yml files)
- [ ] grafana-dashboards/ (with 1 json file)
- [ ] All documentation files (README, GETTING_STARTED, etc.)

---

## 🎯 Your Mission

**Congratulations!** You have a complete monitoring system. Your mission:

1. ✅ Deploy it (Docker or K8s)
2. ✅ Connect your servers
3. ✅ View logs and metrics
4. ✅ Create dashboards
5. ✅ Share with your team

**Good luck!** 🚀

---

**Last Updated:** May 12, 2026

**Version:** 1.0 - Production Ready

**Status:** ✅ Complete & Ready to Deploy
