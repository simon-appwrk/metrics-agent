# Quick Reference Guide

## 🚀 Getting Started (5 Minutes)

### Linux/Mac:
```bash
cp .env.example .env
chmod +x scripts/deploy-docker.sh
./scripts/deploy-docker.sh
```

### Windows:
```cmd
copy .env.example .env
.\scripts\deploy-docker.bat
```

Then open: **http://localhost:3000**

---

## 📊 Common Links

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| Grafana | http://localhost:3000 | admin | admin123 |
| Prometheus | http://localhost:9090 | - | - |
| Loki | http://localhost:3100 | - | - |

---

## 🔧 Essential Commands

### Docker Commands
```bash
# View running services
docker-compose ps

# View service logs
docker-compose logs -f grafana

# Stop all services
docker-compose down

# Restart specific service
docker-compose restart prometheus
```

### Kubernetes Commands
```bash
# Get services status
kubectl get svc -n monitoring

# Get pods status
kubectl get pods -n monitoring

# View pod logs
kubectl logs -n monitoring -l app=grafana

# Delete monitoring stack
kubectl delete namespace monitoring
```

### Remote Server Commands
```bash
# Check Promtail status
sudo systemctl status promtail

# Check Node Exporter status
sudo systemctl status node_exporter

# View Promtail logs
sudo journalctl -u promtail -f

# Restart Promtail
sudo systemctl restart promtail
```

---

## 🔍 Monitoring Queries

### In Loki (Logs)
```
# All errors
{level="error"}

# Specific server
{server="prod-server"}

# Specific application
{job="pm2"}

# Multiple conditions
{job="pm2"} | json | level="error" | severity > "5"
```

### In Prometheus (Metrics)
```promql
# CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))

# Disk usage
100 * (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})
```

---

## 📝 Configuration Files

| File | Purpose | Edit for |
|------|---------|----------|
| `.env` | Environment variables | Change ports, passwords, server IPs |
| `prometheus.yml` | Metric scraping | Add remote servers |
| `loki-config.yml` | Log retention | Change how long to keep logs |
| `docker-compose.yml` | Container setup | Change image versions |

---

## ⚠️ When Something Goes Wrong

### Grafana shows "No Data"
```bash
# Check Loki connection
curl http://localhost:3100/ready

# Check Prometheus targets
# Visit: http://localhost:9090/targets
```

### Remote server logs not appearing
```bash
# On remote server, run:
sudo systemctl restart promtail
sudo journalctl -u promtail -f
```

### Services won't start
```bash
# Check logs
docker-compose logs [service_name]

# Rebuild containers
docker-compose down
docker-compose up -d
```

---

## 🎓 Learning Path

1. **Start here**: Deploy with Docker Compose
2. **Next**: View logs in Grafana using Loki
3. **Then**: Connect a remote server
4. **Advanced**: Setup Kubernetes deployment
5. **Expert**: Create custom dashboards

---

## 📞 Need Help?

- Check the main **README.md**
- See **WINDOWS_SETUP.md** for Windows servers
- Review logs with `docker-compose logs`
- Check official docs at grafana.com/docs

---

**Happy Monitoring! 🎉**
