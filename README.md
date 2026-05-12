# 📊 Grafana + Loki Monitoring Stack

A beginner-friendly, production-ready monitoring solution for collecting logs and metrics from multiple servers using Grafana, Loki, and Prometheus.

## 🎯 Features

- ✅ **Log Aggregation** - Centralized log collection with Loki
- ✅ **Metrics Collection** - Real-time metrics with Prometheus  
- ✅ **Visualization** - Beautiful dashboards with Grafana
- ✅ **Multiple Data Sources** - Support for EC2, VPS, and local machines
- ✅ **Multi-format Logs** - PM2 logs, Docker logs, Syslog
- ✅ **Easy Deployment** - Docker Compose and Kubernetes support
- ✅ **NodePort Services** - Easy access without LoadBalancer
- ✅ **Auto-provisioning** - Datasources and dashboards configured automatically

## 📁 Directory Structure

```
log-metric-alerting/
├── docker-compose.yml                 # Docker Compose configuration
├── loki-config.yml                    # Loki configuration
├── prometheus.yml                     # Prometheus configuration
├── .env.example                       # Environment variables template
│
├── kubernetes/                        # Kubernetes manifests
│   ├── loki-deployment.yml
│   ├── grafana-deployment.yml
│   └── prometheus-deployment.yml
│
├── promtail-config/                   # Log collection configuration
│   └── promtail-config.yml            # For remote servers
│
├── grafana-provisioning/              # Grafana auto-provisioning
│   ├── datasources/
│   │   └── datasources.yml
│   └── dashboards/
│       └── dashboards.yml
│
├── grafana-dashboards/                # Grafana dashboard definitions
│   └── system-dashboard.json
│
├── scripts/                           # Deployment scripts
│   ├── deploy-docker.sh              # Docker deployment (Linux/Mac)
│   ├── deploy-docker.bat             # Docker deployment (Windows)
│   ├── deploy-k8s.sh                 # K8s deployment (Linux/Mac)
│   ├── deploy-k8s.ps1                # K8s deployment (PowerShell)
│   └── setup-remote-server.sh        # Setup remote servers
│
└── README.md                          # This file
```

## 🚀 Quick Start

### Option 1: Docker Compose (Easiest)

**On Windows:**
```bash
# Copy environment template
copy .env.example .env

# Run deployment script
.\scripts\deploy-docker.bat
```

**On Linux/Mac:**
```bash
# Copy environment template
cp .env.example .env

# Run deployment script
chmod +x scripts/deploy-docker.sh
./scripts/deploy-docker.sh
```

Then access:
- 📈 **Grafana**: http://localhost:3000 (admin / admin123)
- 📊 **Prometheus**: http://localhost:9090
- 📝 **Loki**: http://localhost:3100

### Option 2: Kubernetes Deployment

**On Windows (PowerShell):**
```bash
# Ensure kubectl is configured
kubectl config current-context

# Run deployment
.\scripts\deploy-k8s.ps1
```

**On Linux/Mac:**
```bash
# Ensure kubectl is configured
kubectl config current-context

# Run deployment
chmod +x scripts/deploy-k8s.sh
./scripts/deploy-k8s.sh
```

Access via NodePort:
- **Grafana**: http://localhost:30300
- **Prometheus**: http://localhost:30310

## ⚙️ Configuration

### Environment Variables (.env)

Create `.env` from `.env.example` and configure:

```env
# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123
GRAFANA_PORT=3000

# Remote Servers (update with your servers)
REMOTE_SERVER_1_NAME=ec2-server-1
REMOTE_SERVER_1_HOST=10.0.1.100
REMOTE_SERVER_1_PORT=9100

# And so on for other servers...
```

**Important**: Never push `.env` to GitHub! Add it to `.gitignore`.

## 🖥️ Setting Up Remote Servers

### For Each Remote Server (EC2, VPS, or Local Machine):

**Step 1: Copy the setup script**
```bash
# Copy setup-remote-server.sh to your server
scp scripts/setup-remote-server.sh user@server:/tmp/
```

**Step 2: Run setup**
```bash
# SSH into the server
ssh user@server

# Run the setup script
sudo bash /tmp/setup-remote-server.sh <LOKI_CENTRAL_IP> <SERVER_NAME>

# Example:
# sudo bash /tmp/setup-remote-server.sh 192.168.1.100 prod-server-1
```

This will:
- ✅ Install Node Exporter (metrics)
- ✅ Install Promtail (log collection)
- ✅ Configure services to start automatically
- ✅ Setup log scraping for PM2, Docker, Syslog

**Step 3: Update .env on central server**
```env
# Add your remote server details
REMOTE_SERVER_1_HOST=<REMOTE_SERVER_IP>
REMOTE_SERVER_1_PORT=9100
```

**Step 4: Restart monitoring stack**
```bash
# For Docker
docker-compose restart prometheus

# For K8s
kubectl rollout restart deployment/prometheus -n monitoring
```

## 📊 What Gets Collected

### From Remote Servers:

#### Logs:
- **PM2 Logs** - Node.js application logs
- **Docker Logs** - Container logs
- **Syslog** - System logs
- **Application Logs** - Custom application logs in `/var/log/app/`

#### Metrics:
- **CPU Usage** - Usage percentage
- **Memory Usage** - RAM utilization
- **Disk Space** - Storage usage
- **Network I/O** - Network throughput
- **Load Average** - System load
- **Processes** - Running processes
- **File Descriptors** - Open files

### In Grafana:

Default dashboard includes:
- 📈 Real-time CPU usage graph
- 💾 Memory usage gauge
- 📋 Application logs stream

## � Email Alerts with Alertmanager

This stack now includes **Alertmanager** for email alerts. Prometheus sends warning and critical alerts to Alertmanager, and Alertmanager delivers email notifications when rules fire.

Important notes:
- Alertmanager does not need to be publicly exposed for email alerts to work.
- It only needs SMTP access to send email, and Prometheus needs internal access to Alertmanager.
- The recommended public URL to expose is **Grafana** only, unless you want direct access to Prometheus or Alertmanager UIs.

If you want direct access to Alertmanager, you can use a port-forward or a Cloudflare Tunnel to the internal service.

## 🌐 Public URL Guidance

For the NodePort deployment:
- **Grafana** is the main service you should expose publicly if developers need dashboard access.
- **Prometheus** and **Alertmanager** can remain internal or accessible only through SSH port-forward / tunnel.
- **Loki** can also remain internal because Grafana is the UI used for logs.

## 📝 Example: Docker + PM2 Application Server

If one server runs a Docker container called `langgraph-chatbot` and a PM2 app called `reviewmate-backend`, use Promtail and Node Exporter on that server.

### Logs to collect
- Docker logs from `langgraph-chatbot`
- PM2 logs from `reviewmate-backend`
- System logs and host metrics from the server itself

### Promtail example config for that server

```yaml
- job_name: pm2_reviewmate
  static_configs:
    - targets:
        - localhost
      labels:
        job: reviewmate-backend
        server: reviewmate-server
        __path__: /home/*/.pm2/logs/reviewmate-backend*.log

- job_name: docker_langgraph_chatbot
  static_configs:
    - targets:
        - localhost
      labels:
        job: langgraph-chatbot
        server: reviewmate-server
        __path__: /var/lib/docker/containers/*/*-json.log
```

Then add the server to Prometheus (remote exporter on port 9100) using the central `.env` and restart Prometheus.

### Grafana queries

- Docker logs: `{job="langgraph-chatbot"}`
- PM2 logs: `{job="reviewmate-backend"}`
- Server metrics: `node_memory_MemTotal_bytes`, `node_cpu_seconds_total`

## �🛠️ Common Tasks

### View Logs in Grafana

1. Open Grafana: http://localhost:3000
2. Go to **Explore** → Select **Loki** datasource
3. Use queries like:
   ```
   {job="pm2"}           # All PM2 logs
   {server="prod-server-1"}  # Specific server
   {job="pm2", level="error"}  # Error logs only
   ```

### Monitor Metrics in Grafana

1. Go to Grafana dashboards
2. View pre-built "System Monitoring Dashboard"
3. See CPU, memory, disk usage across all servers

### Add Custom Log Path

Edit `/etc/promtail/config.yml` on the remote server:

```yaml
- job_name: my_app
  static_configs:
    - targets:
        - localhost
      labels:
        job: my_application
        __path__: /path/to/my/logs/*.log
```

Then restart Promtail:
```bash
sudo systemctl restart promtail
```

### Stop the Stack

**Docker:**
```bash
docker-compose down
```

**Kubernetes:**
```bash
kubectl delete namespace monitoring
```

## 📝 Prometheus Query Examples

Access at http://localhost:9090

### CPU Metrics
```promql
# CPU idle percentage
node_cpu_seconds_total{mode="idle"}

# CPU usage per server
rate(node_cpu_seconds_total{mode!="idle"}[5m])
```

### Memory Metrics
```promql
# Memory usage percentage
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))

# Available memory
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024  # in GB
```

### Disk Metrics
```promql
# Disk usage percentage
100 * (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes))
```

## 🔍 Troubleshooting

### Grafana can't connect to Loki

**Check:**
- Loki container is running: `docker ps | grep loki`
- Loki is accessible: `curl http://localhost:3100/ready`
- Firewall allows traffic

**Solution:**
```bash
# Restart Loki
docker-compose restart loki

# Or check logs
docker-compose logs loki
```

### No logs appearing in Grafana

**Check:**
- Promtail is running on remote server: `systemctl status promtail`
- Network connectivity: `ping <LOKI_SERVER_IP>`
- Log paths exist: `ls /var/log/syslog`

**Solution:**
```bash
# Tail promtail logs
journalctl -u promtail -f

# Check Promtail config
cat /etc/promtail/config.yml

# Restart Promtail
sudo systemctl restart promtail
```

### Prometheus not scraping metrics

**Check:**
- Node Exporter running: `systemctl status node_exporter`
- Metrics accessible: `curl http://localhost:9100/metrics`
- Prometheus config has correct targets

**Solution:**
```bash
# Restart Node Exporter
sudo systemctl restart node_exporter

# Check Prometheus targets at: http://localhost:9090/targets
```

### High memory usage

**Check:**
- Loki retention period in loki-config.yml
- Prometheus storage retention in prometheus.yml

**Reduce retention:**
```yaml
# In loki-config.yml
table_manager:
  retention_period: 72h  # Keep only 3 days

# In prometheus.yml
storage.tsdb.retention.time=14d  # Keep only 14 days
```

## 🔐 Security Considerations

For production use:

1. **Change default passwords** in .env
   ```env
   GRAFANA_ADMIN_PASSWORD=your-secure-password
   ```

2. **Use SSL/TLS** for remote connections
   - Setup reverse proxy (nginx/traefik)
   - Use certificates

3. **Restrict access**
   - Use NetworkPolicy in K8s
   - Configure firewall rules
   - Use VPN for remote servers

4. **Backup data**
   - Backup Grafana dashboards regularly
   - Archive important logs

## 📈 Scaling

For multiple environments:

1. **Create separate stacks** - Dev, Staging, Production
2. **Use different namespaces** in K8s
3. **Separate databases** - Don't mix environments
4. **Regional deployments** - Deploy monitoring stack per region

## 📚 Resources

- [Grafana Docs](https://grafana.com/docs/)
- [Loki Docs](https://grafana.com/docs/loki/)
- [Prometheus Docs](https://prometheus.io/docs/)
- [Node Exporter Docs](https://github.com/prometheus/node_exporter)
- [Promtail Docs](https://grafana.com/docs/loki/latest/clients/promtail/)

## 📞 Support

For issues or questions:
1. Check troubleshooting section
2. Review logs with `docker-compose logs` or `kubectl logs`
3. Check GitHub issues
4. Consult official documentation

## 📄 License

This project is open source and available under the MIT License.

---

**Happy Monitoring! 🎉**
