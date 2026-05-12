# Remote Server Setup — Metrics & Logs

This document describes what to install on each **monitored server** (the box whose metrics and logs you want to ship to your central Loki + Prometheus stack).

Tested on **Ubuntu 22.04 / 24.04**. The central stack is assumed to be running on `master3` (K8s monitoring namespace) or any host exposing Loki on port `3100` and reachable from this server.

---

## 1. What gets installed

Two agents run as systemd services on every monitored server:

| Component       | Purpose                                                | Listens on |
|-----------------|--------------------------------------------------------|------------|
| `node_exporter` | Exposes host CPU / memory / disk / network metrics     | `:9100`    |
| `promtail`      | Tails log files and pushes them to Loki                | `:9080`    |

`node_exporter` is **pulled** by Prometheus (Prometheus initiates the scrape).
`promtail` **pushes** logs to Loki (the agent initiates the connection).

---

## 2. Prerequisites on the remote server

```bash
sudo apt update
sudo apt install -y curl wget unzip tar
```

Open the following inbound ports on the remote server's firewall so the central Prometheus can scrape metrics:

```bash
# allow Prometheus on master3 to reach node_exporter
sudo ufw allow from <MASTER3_IP> to any port 9100 proto tcp
```

`promtail` only needs **outbound** access to Loki, so no extra inbound rule is required for it (port `9080` is local-only diagnostics).

---

## 3. Automated install (recommended)

The repo ships a one-shot installer that does everything below. From the remote server:

```bash
# copy the script onto the remote server, then:
sudo ./setup-remote-server.sh <LOKI_SERVER_IP> <SERVER_NAME>
```

Arguments:
- `<LOKI_SERVER_IP>` — IP of the host where Loki is reachable (e.g. master3's node IP if Loki is exposed via NodePort, or the LoadBalancer/Ingress IP).
- `<SERVER_NAME>` — label used in Grafana to identify this server (e.g. `app-server-1`).

Verify after install:
```bash
systemctl status node_exporter
systemctl status promtail
curl -s http://localhost:9100/metrics | head        # should show node_* metrics
curl -s http://localhost:9080/ready                  # promtail readiness
```

---

## 4. Manual install (if you'd rather do it step by step)

### 4.1 Install Node Exporter

```bash
sudo useradd --no-create-home --shell /bin/false node_exporter

VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest \
  | grep tag_name | cut -d '"' -f 4)
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/${VERSION}/node_exporter-${VERSION#v}.linux-amd64.tar.gz
tar xvfz node_exporter-${VERSION#v}.linux-amd64.tar.gz
sudo cp node_exporter-${VERSION#v}.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
```

Create the systemd unit:

```bash
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($|/) \
  --collector.netdev.device-exclude=^(veth.*)
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
```

### 4.2 Install Promtail

```bash
sudo useradd --no-create-home --shell /bin/false promtail

VERSION=$(curl -s https://api.github.com/repos/grafana/loki/releases/latest \
  | grep tag_name | cut -d '"' -f 4)
cd /tmp
wget https://github.com/grafana/loki/releases/download/${VERSION}/promtail-${VERSION}.linux-amd64.zip
unzip promtail-${VERSION}.linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod a+x /usr/local/bin/promtail
```

Create config — replace `LOKI_SERVER_IP` and `SERVER_NAME`:

```bash
sudo mkdir -p /etc/promtail
sudo tee /etc/promtail/config.yml > /dev/null <<'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/promtail_positions.yaml

clients:
  - url: http://LOKI_SERVER_IP:3100/loki/api/v1/push
    tenant_id: production

scrape_configs:
  - job_name: syslog
    static_configs:
      - targets: [localhost]
        labels:
          job: syslog
          server: SERVER_NAME
          __path__: /var/log/syslog

  - job_name: pm2_logs
    static_configs:
      - targets: [localhost]
        labels:
          job: pm2
          server: SERVER_NAME
          __path__: /home/*/.pm2/logs/*.log

  - job_name: docker_logs
    static_configs:
      - targets: [localhost]
        labels:
          job: docker
          server: SERVER_NAME
          __path__: /var/lib/docker/containers/*/*-json.log

  - job_name: app_logs
    static_configs:
      - targets: [localhost]
        labels:
          job: application
          server: SERVER_NAME
          __path__: /var/log/app/*.log
EOF

# Promtail needs to read /var/log/syslog and docker logs
sudo usermod -aG adm,docker promtail 2>/dev/null || sudo usermod -aG adm promtail
sudo chown -R promtail:promtail /etc/promtail
```

Create the systemd unit:

```bash
sudo tee /etc/systemd/system/promtail.service > /dev/null <<'EOF'
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

sudo systemctl daemon-reload
sudo systemctl enable --now promtail
```

---

## 5. Register the new server in Prometheus

On `master3`, edit the Prometheus ConfigMap and add a scrape job for the new host's node_exporter:

```bash
kubectl edit configmap prometheus-config -n monitoring
```

Under `scrape_configs:` in `prometheus.yml`, add:

```yaml
      - job_name: 'remote-server-1'
        static_configs:
          - targets: ['<REMOTE_SERVER_IP>:9100']
            labels:
              server_name: 'app-server-1'
```

Then force Prometheus to reload:

```bash
kubectl rollout restart deployment/prometheus -n monitoring
```

Promtail does not need any server-side registration — it auto-streams to Loki as soon as it starts.

---

## 6. Verify end-to-end

| Check | Command / URL |
|------|----------------|
| Metrics reaching Prometheus | Open Prometheus UI → Status → Targets, ensure the new job is `UP` |
| Logs reaching Loki | In Grafana → Explore → Loki datasource → `{server="app-server-1"}` |
| Agent health on remote | `systemctl status node_exporter promtail` |
| Agent logs on remote | `journalctl -u node_exporter -f` / `journalctl -u promtail -f` |

---

## 7. Troubleshooting

- **Prometheus shows target `DOWN`** — confirm `:9100` is reachable from `master3`:
  `curl -s http://<REMOTE_IP>:9100/metrics | head`. If it times out, check `ufw`/security groups.
- **Promtail running but no logs in Grafana** — check `journalctl -u promtail -n 50`; common causes are wrong Loki URL, file permissions on `/var/log/syslog`, or the `tenant_id` mismatch (Loki must have `auth_enabled: false` or accept tenant `production`).
- **Docker logs missing** — Promtail's user must be in the `docker` group, or run Promtail as root (less ideal).
