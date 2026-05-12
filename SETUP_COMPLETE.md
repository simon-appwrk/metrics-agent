# Grafana + Loki Stack - Setup Complete! ✅

Welcome to your monitoring stack! Here's what has been created:

## 📦 What You Have

### Core Services
- ✅ **Grafana** - Dashboard and visualization
- ✅ **Loki** - Log aggregation  
- ✅ **Prometheus** - Metrics collection
- ✅ **Node Exporter** - Server metrics

### Deployment Options
- ✅ **Docker Compose** - For local development & testing
- ✅ **Kubernetes** - For production K8s clusters
- ✅ **Remote Server Setup** - For Linux & Windows servers

### Documentation
- ✅ **README.md** - Complete guide (START HERE)
- ✅ **QUICK_START.md** - Quick reference
- ✅ **WINDOWS_SETUP.md** - Windows server guide

---

## 🎯 Next Steps (Choose One)

### Option A: Test Locally (5 minutes)
```bash
cp .env.example .env

# On Windows
.\scripts\deploy-docker.bat

# On Linux/Mac
chmod +x scripts/deploy-docker.sh
./scripts/deploy-docker.sh
```

Then visit: **http://localhost:3000** (admin / admin123)

### Option B: Deploy to Kubernetes
```bash
cp .env.example .env

# On Windows PowerShell
.\scripts\deploy-k8s.ps1

# On Linux/Mac
chmod +x scripts/deploy-k8s.sh
./scripts/deploy-k8s.sh
```

### Option C: Prepare for Remote Servers
1. Deploy central stack (Option A or B)
2. Copy `scripts/setup-remote-server.sh` to each remote server
3. Run setup on each server with central server IP

---

## 📁 File Structure

```
log-metric-alerting/
├── docker-compose.yml              ← Main config for Docker
├── loki-config.yml                 ← Loki settings
├── prometheus.yml                  ← Prometheus targets
├── .env.example                    ← Copy this to .env
├── .gitignore                      ← Prevents .env from being committed
│
├── README.md                       ← FULL DOCUMENTATION (read this!)
├── QUICK_START.md                  ← Fast reference
├── WINDOWS_SETUP.md                ← For Windows servers
│
├── kubernetes/                     ← K8s manifests
│   ├── loki-deployment.yml
│   ├── grafana-deployment.yml
│   └── prometheus-deployment.yml
│
├── scripts/                        ← Deploy scripts
│   ├── deploy-docker.sh          ← Linux/Mac Docker
│   ├── deploy-docker.bat         ← Windows Docker
│   ├── deploy-k8s.sh             ← Linux/Mac Kubernetes
│   ├── deploy-k8s.ps1            ← Windows Kubernetes
│   └── setup-remote-server.sh    ← Remote server setup
│
├── promtail-config/                ← Log collection config
│   └── promtail-config.yml
│
└── grafana-provisioning/           ← Auto-setup configs
    ├── datasources/
    │   └── datasources.yml
    └── dashboards/
        └── dashboards.yml
```

---

## 🚦 Getting Started Checklist

### Before First Run
- [ ] Copy `.env.example` to `.env`
- [ ] Read **README.md** for full documentation
- [ ] Check you have Docker installed (for Docker option)
- [ ] Check you have kubectl configured (for K8s option)

### First Run
- [ ] Run appropriate deploy script
- [ ] Wait for services to start (2-3 minutes)
- [ ] Access Grafana on http://localhost:3000
- [ ] Check that Loki is added as datasource

### To Add Remote Servers
- [ ] Copy `setup-remote-server.sh` to remote server
- [ ] Run setup with your central server IP
- [ ] Add server IP to Prometheus config
- [ ] Restart Prometheus

---

## 🎓 Learning Resources

### For Beginners
1. **README.md** - Start here for overview
2. **QUICK_START.md** - Fast commands reference
3. Try Docker option first - easiest to understand

### For Advanced Users
1. Review K8s manifests in `kubernetes/` folder
2. Customize `prometheus.yml` for your infrastructure
3. Create custom Grafana dashboards
4. Setup alerts and notifications

---

## 💡 Key Concepts (Simple Explanation)

### What This Stack Does
- **Collects** metrics (CPU, memory) from servers
- **Collects** logs (from applications, Docker, PM2)
- **Stores** everything securely
- **Visualizes** with beautiful dashboards

### Architecture
```
Your Servers → Node Exporter & Promtail
              ↓
         Central Stack
              ↓
    Prometheus (metrics) + Loki (logs)
              ↓
         Grafana (dashboards)
              ↓
         You can see everything!
```

### Three Ways to Deploy
1. **Docker Compose** - Best for learning & testing
2. **Kubernetes** - Best for production
3. **Remote Servers** - Multiple servers across locations

---

## ⚠️ Important Reminders

### Security
- Change admin password in `.env` before production
- Never commit `.env` to GitHub (it's in .gitignore)
- Use SSL/TLS for remote connections in production

### Customization
- Edit `.env` to change ports and passwords
- Edit `prometheus.yml` to add your servers
- Edit `promtail-config.yml` on remote servers for custom logs

### First Time Issues?
- Read **README.md** section "Troubleshooting"
- Check logs: `docker-compose logs`
- Or: `kubectl logs -n monitoring ...`

---

## 🎯 Common Tasks

### Add a new remote server
1. Update `.env` with server IP
2. Run `setup-remote-server.sh` on that server
3. Restart Prometheus
4. Done!

### View application logs
1. Go to Grafana
2. Click "Explore"
3. Select "Loki"
4. Type: `{job="pm2"}`

### Create custom dashboard
1. In Grafana, click "+" → "Dashboard"
2. Add panels with queries
3. Save and name it

---

## 📊 What You Can Monitor

### Per Server
- CPU usage (%)
- Memory usage (%)
- Disk space (%)
- Network traffic
- Load average
- Running processes
- Open files

### Application Logs
- PM2 application logs
- Docker container logs
- System logs (syslog)
- Custom application logs

---

## 🎉 Success!

**Congratulations!** Your monitoring stack is ready to deploy.

### Your Next Move:
1. Choose Docker or Kubernetes
2. Run the deployment script
3. Visit Grafana dashboard
4. Add your first remote server

**Questions?** Check README.md - it has everything!

---

**Happy Monitoring! 📊**
