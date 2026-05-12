#!/bin/bash
# ==========================================
# REMOTE SERVER SETUP - PROMTAIL & NODE EXPORTER
# ==========================================
# Run this script on each remote server to collect logs and metrics
# Usage: ./setup-remote-server.sh <LOKI_SERVER_IP> <SERVER_NAME>

set -e

LOKI_SERVER_IP=${1:-"192.168.1.100"}
SERVER_NAME=${2:-"$(hostname)"}
LOKI_PORT=3100

echo "======================================"
echo "Setting up Remote Server Monitoring"
echo "======================================"
echo "Loki Server: $LOKI_SERVER_IP"
echo "Server Name: $SERVER_NAME"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   exit 1
fi

echo "✅ Running as root"
echo ""

# ==========================================
# INSTALL NODE EXPORTER
# ==========================================
echo "🚀 Installing Node Exporter..."

# Create user for node exporter
if ! id "node_exporter" &>/dev/null; then
    useradd --no-create-home --shell /bin/false node_exporter
    echo "✅ Created node_exporter user"
else
    echo "✅ node_exporter user already exists"
fi

# Download and install node exporter
LATEST_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/${LATEST_VERSION}/node_exporter-${LATEST_VERSION#v}.linux-amd64.tar.gz
tar xvfz node_exporter-${LATEST_VERSION#v}.linux-amd64.tar.gz
cp node_exporter-${LATEST_VERSION#v}.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf node_exporter-${LATEST_VERSION#v}.linux-amd64*

echo "✅ Node Exporter installed"
echo ""

# ==========================================
# CREATE SYSTEMD SERVICE FOR NODE EXPORTER
# ==========================================
echo "📝 Creating Node Exporter systemd service..."

cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \\
  --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(\$|/) \\
  --collector.netdev.device-exclude=^(veth.*)

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo "✅ Node Exporter service started"
echo ""

# ==========================================
# INSTALL PROMTAIL
# ==========================================
echo "🚀 Installing Promtail..."

# Create user for promtail
if ! id "promtail" &>/dev/null; then
    useradd --no-create-home --shell /bin/false promtail
    echo "✅ Created promtail user"
else
    echo "✅ promtail user already exists"
fi

# Download and install promtail
LATEST_VERSION=$(curl -s https://api.github.com/repos/grafana/loki/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
cd /tmp
wget https://github.com/grafana/loki/releases/download/${LATEST_VERSION}/promtail-${LATEST_VERSION}.linux-amd64.zip
unzip promtail-${LATEST_VERSION}.linux-amd64.zip
mv promtail-linux-amd64 /usr/local/bin/promtail
chmod a+x /usr/local/bin/promtail
rm -f promtail-${LATEST_VERSION}.linux-amd64.zip

echo "✅ Promtail installed"
echo ""

# ==========================================
# CREATE PROMTAIL CONFIGURATION
# ==========================================
echo "📝 Creating Promtail configuration..."

mkdir -p /etc/promtail
chown promtail:promtail /etc/promtail

cat > /etc/promtail/config.yml <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/promtail_positions.yaml

clients:
  - url: http://$LOKI_SERVER_IP:$LOKI_PORT/loki/api/v1/push
    tenant_id: production

scrape_configs:
  # PM2 Logs
  - job_name: pm2_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: pm2
          server: $SERVER_NAME
          __path__: /home/*/.pm2/logs/*.log

  # Syslog
  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          server: $SERVER_NAME
          __path__: /var/log/syslog

  # Docker Logs (if Docker is running)
  - job_name: docker_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          server: $SERVER_NAME
          __path__: /var/lib/docker/containers/*/*-json.log

  # Application Logs
  - job_name: app_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: application
          server: $SERVER_NAME
          __path__: /var/log/app/*.log
EOF

chown promtail:promtail /etc/promtail/config.yml

echo "✅ Promtail configuration created"
echo ""

# ==========================================
# CREATE SYSTEMD SERVICE FOR PROMTAIL
# ==========================================
echo "📝 Creating Promtail systemd service..."

cat > /etc/systemd/system/promtail.service <<EOF
[Unit]
Description=Promtail
After=network.target

[Service]
User=promtail
Group=promtail
Type=simple
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable promtail
systemctl start promtail

echo "✅ Promtail service started"
echo ""

# ==========================================
# VERIFY INSTALLATION
# ==========================================
echo "======================================"
echo "✅ Remote Server Setup Complete!"
echo "======================================"
echo ""

echo "📊 Service Status:"
systemctl status node_exporter --no-pager
echo ""
systemctl status promtail --no-pager
echo ""

echo "🔍 Verification:"
echo "  Node Exporter: http://$(hostname -I | awk '{print $1}'):9100/metrics"
echo "  Promtail HTTP: http://$(hostname -I | awk '{print $1}'):9080"
echo ""

echo "📝 To view service logs:"
echo "  Node Exporter: journalctl -u node_exporter -f"
echo "  Promtail:      journalctl -u promtail -f"
echo ""
