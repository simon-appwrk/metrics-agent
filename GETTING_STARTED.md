# 🎯 Getting Started - Step by Step

## Choose Your Path

### ✅ Path 1: I Want to Test Locally (5 minutes)

**Did you choose Docker? Follow this:**

**Step 1**: Copy configuration
```bash
# Windows
copy .env.example .env

# Linux/Mac
cp .env.example .env
```

**Step 2**: Run deployment
```bash
# Windows
.\scripts\deploy-docker.bat

# Linux/Mac
chmod +x scripts/deploy-docker.sh
./scripts/deploy-docker.sh
```

**Step 3**: Wait for green checkmarks ✅

**Step 4**: Open browser
```
http://localhost:3000
Username: admin
Password: admin123
```

**Step 5**: Explore!
- Click "Explore" on sidebar
- Select "Loki" 
- You'll see local logs!

---

### ✅ Path 2: I Want to Use Kubernetes (10 minutes)

**Did you choose Kubernetes? Follow this:**

**Step 1**: Make sure kubectl is ready
```bash
kubectl cluster-info
```

**Step 2**: Copy configuration
```bash
# Windows
copy .env.example .env

# Linux/Mac
cp .env.example .env
```

**Step 3**: Run deployment
```bash
# Windows PowerShell
.\scripts\deploy-k8s.ps1

# Linux/Mac
chmod +x scripts/deploy-k8s.sh
./scripts/deploy-k8s.sh
```

**Step 4**: Wait for pods to be ready
```bash
kubectl get pods -n monitoring
```

**Step 5**: Open browser (using NodePort)
```
http://localhost:30300
Username: admin
Password: admin123
```

---

### ✅ Path 3: I Want Multiple Servers (20 minutes)

**You already deployed? Now add remote servers:**

**Step 1**: Deploy central stack (Path 1 or 2)

**Step 2**: Choose remote servers to monitor
- List your servers: EC2, VPS, or local machines
- Get their IPs

**Step 3**: Update .env on central server
```env
REMOTE_SERVER_1_NAME=my-server-1
REMOTE_SERVER_1_HOST=192.168.1.100
REMOTE_SERVER_1_PORT=9100

REMOTE_SERVER_2_NAME=my-server-2
REMOTE_SERVER_2_HOST=192.168.1.101
REMOTE_SERVER_2_PORT=9100
```

**Step 4**: On each remote server, run setup
```bash
# From central server, copy script to remote
scp scripts/setup-remote-server.sh user@remote-server:/tmp/

# SSH into remote
ssh user@remote-server

# Run with your central server IP
sudo bash /tmp/setup-remote-server.sh 192.168.1.50 my-server-1
```

**Step 5**: Restart Prometheus
```bash
# Docker
docker-compose restart prometheus

# Kubernetes
kubectl rollout restart deployment/prometheus -n monitoring
```

**Step 6**: Check Prometheus targets
```
http://localhost:9090/targets
```
You should see all remote servers in green! ✅

---

## 🚨 Alertmanager and Email Notifications

This stack includes Alertmanager for email alerts. You can configure SMTP details in `alertmanager/alertmanager.yml` and use the built-in rules from `alerts.yml`.

> For most use cases, only **Grafana** needs a public URL. Prometheus and Alertmanager can stay internal and be accessed through SSH port-forward or a tunnel.

---

## 🧪 Example: One Server with Docker + PM2

If one server runs a Docker container named `langgraph-chatbot` and a PM2 service named `reviewmate-backend`, use Promtail to collect both logs and Node Exporter to expose server metrics.

### Example Promtail config for this server
```yaml
- job_name: pm2_reviewmate
  static_configs:
    - targets:
        - localhost
      labels:
        job: reviewmate-backend
        __path__: /home/*/.pm2/logs/reviewmate-backend*.log

- job_name: docker_langgraph_chatbot
  static_configs:
    - targets:
        - localhost
      labels:
        job: langgraph-chatbot
        __path__: /var/lib/docker/containers/*/*-json.log
```

Then restart Promtail and confirm logs appear in Grafana using queries like:
- `{job="reviewmate-backend"}`
- `{job="langgraph-chatbot"}`

---

## 🎓 What Happens Next?

### In Grafana, You Can:

1. **View Logs**
   - Click "Explore"
   - Select "Loki"
   - Type queries like: `{job="pm2"}`
   - See all logs from your servers!

2. **View Metrics**
   - Go to "Dashboards"
   - Open "System Monitoring Dashboard"
   - See CPU, Memory, Disk usage across servers!

3. **Create Dashboards**
   - Click "+" → "Dashboard"
   - Add panels with your queries
   - Share with team!

---

## 📋 Important Files to Know

| File | What to Edit | When to Edit |
|------|-------------|-----|
| `.env` | Server IPs, passwords, ports | Before first run, when adding servers |
| `prometheus.yml` | Remote server targets | When manually adding servers (optional) |
| `loki-config.yml` | Log retention | If running out of disk space |
| `docker-compose.yml` | Resource limits | If services need more CPU/memory |

---

## ⚠️ Common First-Time Questions

### "Nothing is showing up in Grafana!"
- **Wait 2-3 minutes** for services to start
- Check health: `curl http://localhost:3100/ready`
- Check logs: `docker-compose logs`

### "I don't see logs from remote servers!"
- Did you run `setup-remote-server.sh` on the remote?
- Is the remote server IP correct in `.env`?
- Did you restart Prometheus?
- Check: `ssh remote-server` → `sudo systemctl status promtail`

### "I get 'Connection Refused' errors"
- Docker/K8s services might still be starting
- Wait 2-3 more minutes
- Check: `docker-compose ps` or `kubectl get pods -n monitoring`

### "I changed the password but still can't login!"
- Restart Grafana:
  - Docker: `docker-compose restart grafana`
  - K8s: `kubectl rollout restart deployment/grafana -n monitoring`

---

## 🚀 Advanced: Customizing for Your Apps

### If you have PM2 apps:
- Logs are automatically collected! 
- They appear in Grafana with `{job="pm2"}`
- No extra configuration needed!

### If you have Docker containers:
- Docker logs are automatically collected!
- They appear with `{job="docker"}`
- No extra configuration needed!

### If you have custom application logs:
- Edit `promtail-config.yml` on remote server
- Add your log path:
  ```yaml
  - job_name: my_app
    static_configs:
      - targets:
          - localhost
        labels:
          job: my_application
          __path__: /path/to/my/logs/*.log
  ```
- Restart Promtail: `sudo systemctl restart promtail`
- Done! Check Grafana!

---

## 📊 Test It Out!

### Try these queries in Grafana:

**See logs from specific server:**
```
{server="my-server-1"}
```

**See error logs only:**
```
{level="error"}
```

**See PM2 app logs:**
```
{job="pm2"}
```

**See CPU spikes:**
```
rate(node_cpu_seconds_total{mode!="idle"}[5m])
```

**See memory usage:**
```
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))
```

---

## ✅ You're Ready!

Choose your path above and get started. The whole team can monitor infrastructure in minutes! 🎉

---

**Questions?** Read the relevant guide:
- Local testing → README.md
- Kubernetes → README.md (K8s section)
- Windows servers → WINDOWS_SETUP.md
- Architecture → ARCHITECTURE.md
