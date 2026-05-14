#!/bin/bash
# ==========================================
# REMOTE SERVER MONITORING AGENT INSTALLER
# ==========================================
# Installs three systemd services on the remote server:
#   - node_exporter  (collects host metrics on 127.0.0.1:9100)
#   - promtail       (pushes logs to Loki via HTTPS + HTTP Basic Auth)
#   - prom-agent     (Prometheus in agent mode — scrapes node_exporter,
#                     remote_writes to central Prometheus via HTTPS + Basic Auth)
#
# Designed for a domain-only central stack (e.g. Cloudflare Tunnel) where the
# remote server has no public IP. All endpoints are HTTPS domains and auth
# is enforced by the central nginx auth-proxy via HTTP Basic Auth.
#
# Configuration is read from /etc/monitoring-agent/.env
# A template is at scripts/remote-agent.env.example.
#
# Usage:
#   sudo cp remote-agent.env.example /etc/monitoring-agent/.env
#   sudo chmod 600 /etc/monitoring-agent/.env
#   # edit /etc/monitoring-agent/.env and fill in real values
#   sudo ./setup-remote-server.sh
#
# Override the env file location with:
#   sudo AGENT_ENV_FILE=/path/to/.env ./setup-remote-server.sh

set -euo pipefail

AGENT_ENV_FILE="${AGENT_ENV_FILE:-/etc/monitoring-agent/.env}"

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (sudo)."
   exit 1
fi

if [[ ! -f "$AGENT_ENV_FILE" ]]; then
   echo "ERROR: env file not found at $AGENT_ENV_FILE"
   echo "       Copy scripts/remote-agent.env.example there and fill it in."
   exit 1
fi

# Lock down the env file before we read it
chmod 600 "$AGENT_ENV_FILE"
chown root:root "$AGENT_ENV_FILE"

# shellcheck disable=SC1090
set -a
. "$AGENT_ENV_FILE"
set +a

SERVER_NAME="${SERVER_NAME:-$(hostname)}"
LOKI_TENANT_ID="${LOKI_TENANT_ID:-production}"
SCRAPE_INTERVAL="${SCRAPE_INTERVAL:-15s}"

# Required vars
for var in LOKI_PUSH_URL PROM_REMOTE_WRITE_URL AUTH_USERNAME AUTH_PASSWORD; do
    if [[ -z "${!var:-}" ]]; then
        echo "ERROR: $var is empty in $AGENT_ENV_FILE"
        exit 1
    fi
done

echo "=========================================="
echo "Remote monitoring agent installer"
echo "=========================================="
echo "Server name           : $SERVER_NAME"
echo "Loki push URL         : $LOKI_PUSH_URL"
echo "Prom remote_write URL : $PROM_REMOTE_WRITE_URL"
echo "Auth username         : $AUTH_USERNAME"
echo "Auth password         : (redacted, ${#AUTH_PASSWORD} chars)"
echo "=========================================="
echo ""

apt-get update -y
apt-get install -y curl wget unzip tar

# ==========================================
# 1. node_exporter (host metrics on :9100)
# ==========================================
echo ">>> Installing node_exporter ..."

if ! id node_exporter &>/dev/null; then
    useradd --no-create-home --shell /bin/false node_exporter
fi

NODE_VERSION=$(curl -fsSL https://api.github.com/repos/prometheus/node_exporter/releases/latest \
    | grep '"tag_name"' | cut -d '"' -f 4)
NODE_VERSION_NO_V="${NODE_VERSION#v}"

cd /tmp
wget -q "https://github.com/prometheus/node_exporter/releases/download/${NODE_VERSION}/node_exporter-${NODE_VERSION_NO_V}.linux-amd64.tar.gz"
tar xzf "node_exporter-${NODE_VERSION_NO_V}.linux-amd64.tar.gz"
install -m 0755 -o node_exporter -g node_exporter \
    "node_exporter-${NODE_VERSION_NO_V}.linux-amd64/node_exporter" /usr/local/bin/node_exporter
rm -rf "node_exporter-${NODE_VERSION_NO_V}.linux-amd64"*

cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
# Bind only to localhost — metrics are shipped out via prom-agent remote_write,
# so there is no need to expose :9100 to the network.
ExecStart=/usr/local/bin/node_exporter \\
  --web.listen-address=127.0.0.1:9100 \\
  --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(\$|/) \\
  --collector.netdev.device-exclude=^(veth.*)
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now node_exporter

# ==========================================
# 2. promtail (push logs to Loki with HTTP Basic Auth)
# ==========================================
echo ">>> Installing promtail ..."

if ! id promtail &>/dev/null; then
    useradd --no-create-home --shell /bin/false promtail
fi

# Promtail is EOL'd by Grafana — last release that shipped a standalone
# promtail binary is v3.0.0. Loki v3.4+ no longer ships promtail-*.zip.
# v3.0.0 talks to Loki 3.x server fine.
LOKI_VERSION=v3.0.0
LOKI_VERSION_NO_V="${LOKI_VERSION#v}"

cd /tmp
wget -q "https://github.com/grafana/loki/releases/download/${LOKI_VERSION}/promtail-${LOKI_VERSION_NO_V}.linux-amd64.zip"
unzip -o "promtail-${LOKI_VERSION_NO_V}.linux-amd64.zip" >/dev/null
install -m 0755 promtail-linux-amd64 /usr/local/bin/promtail
rm -f "promtail-${LOKI_VERSION_NO_V}.linux-amd64.zip" promtail-linux-amd64

mkdir -p /etc/promtail
mkdir -p /var/lib/promtail

# Promtail needs to read /var/log/syslog and docker logs
usermod -aG adm promtail
if getent group docker >/dev/null; then
    usermod -aG docker promtail
fi

# The YAML references ${AUTH_USERNAME} / ${AUTH_PASSWORD} as literal placeholders.
# Promtail's `-config.expand-env=true` flag expands them at startup using the
# variables that systemd loads from EnvironmentFile=. The actual password is
# NOT written into the YAML on disk.
cat > /etc/promtail/config.yml <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: ${LOKI_PUSH_URL}
    tenant_id: ${LOKI_TENANT_ID}
    basic_auth:
      username: \${AUTH_USERNAME}
      password: \${AUTH_PASSWORD}

scrape_configs:
  - job_name: syslog
    static_configs:
      - targets: [localhost]
        labels:
          job: syslog
          server: ${SERVER_NAME}
          __path__: /var/log/syslog

  - job_name: pm2_logs
    static_configs:
      - targets: [localhost]
        labels:
          job: pm2
          server: ${SERVER_NAME}
          __path__: /home/*/.pm2/logs/*.log

  - job_name: docker_logs
    static_configs:
      - targets: [localhost]
        labels:
          job: docker
          server: ${SERVER_NAME}
          __path__: /var/lib/docker/containers/*/*-json.log

  - job_name: app_logs
    static_configs:
      - targets: [localhost]
        labels:
          job: application
          server: ${SERVER_NAME}
          __path__: /var/log/app/*.log
EOF

chown -R promtail:promtail /etc/promtail /var/lib/promtail

cat > /etc/systemd/system/promtail.service <<EOF
[Unit]
Description=Promtail log shipper
After=network-online.target
Wants=network-online.target

[Service]
User=promtail
Group=promtail
Type=simple
EnvironmentFile=${AGENT_ENV_FILE}
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml -config.expand-env=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now promtail

# ==========================================
# 3. prom-agent (Prometheus in agent mode + Basic Auth)
# ==========================================
echo ">>> Installing prom-agent ..."

if ! id prom_agent &>/dev/null; then
    useradd --no-create-home --shell /bin/false prom_agent
fi

PROM_VERSION=$(curl -fsSL https://api.github.com/repos/prometheus/prometheus/releases/latest \
    | grep '"tag_name"' | cut -d '"' -f 4)
PROM_VERSION_NO_V="${PROM_VERSION#v}"

cd /tmp
wget -q "https://github.com/prometheus/prometheus/releases/download/${PROM_VERSION}/prometheus-${PROM_VERSION_NO_V}.linux-amd64.tar.gz"
tar xzf "prometheus-${PROM_VERSION_NO_V}.linux-amd64.tar.gz"
install -m 0755 "prometheus-${PROM_VERSION_NO_V}.linux-amd64/prometheus" /usr/local/bin/prom-agent
rm -rf "prometheus-${PROM_VERSION_NO_V}.linux-amd64"*

mkdir -p /etc/prom-agent
mkdir -p /var/lib/prom-agent

# Prometheus does NOT support env-var expansion in basic_auth.password, so we
# use `password_file:` and write the password to a 0600 file owned by the
# prom_agent user. The .env file remains the single source of truth.
umask 077
printf '%s' "$AUTH_PASSWORD" > /etc/prom-agent/password
chown prom_agent:prom_agent /etc/prom-agent/password
chmod 600 /etc/prom-agent/password

cat > /etc/prom-agent/agent.yml <<EOF
global:
  scrape_interval: ${SCRAPE_INTERVAL}
  external_labels:
    server: ${SERVER_NAME}

scrape_configs:
  - job_name: node-exporter
    static_configs:
      - targets: ['127.0.0.1:9100']
        labels:
          server: ${SERVER_NAME}

remote_write:
  - url: ${PROM_REMOTE_WRITE_URL}
    basic_auth:
      username: ${AUTH_USERNAME}
      password_file: /etc/prom-agent/password
EOF

chown -R prom_agent:prom_agent /etc/prom-agent /var/lib/prom-agent
chmod 640 /etc/prom-agent/agent.yml

cat > /etc/systemd/system/prom-agent.service <<EOF
[Unit]
Description=Prometheus (agent mode) — metric shipper
After=network-online.target node_exporter.service
Wants=network-online.target

[Service]
User=prom_agent
Group=prom_agent
Type=simple
ExecStart=/usr/local/bin/prom-agent \\
  --config.file=/etc/prom-agent/agent.yml \\
  --enable-feature=agent \\
  --storage.agent.path=/var/lib/prom-agent \\
  --web.listen-address=127.0.0.1:9091
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now prom-agent

# ==========================================
# Done
# ==========================================
echo ""
echo "=========================================="
echo "Setup complete. Service status:"
echo "=========================================="
for svc in node_exporter promtail prom-agent; do
    state=$(systemctl is-active "$svc" || true)
    echo "  $svc : $state"
done
echo ""
echo "Logs:"
echo "  journalctl -u node_exporter -f"
echo "  journalctl -u promtail       -f"
echo "  journalctl -u prom-agent     -f"
echo ""
echo "Local checks:"
echo "  curl -s http://127.0.0.1:9100/metrics | head"
echo "  curl -s http://127.0.0.1:9080/ready    # promtail"
echo "  curl -s http://127.0.0.1:9091/-/ready  # prom-agent"
