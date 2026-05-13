# Remote Server Setup — Metrics & Logs (domain + Cloudflare Access)

This document describes how to ship **logs** and **metrics** from a remote
server to the central Loki + Prometheus + Grafana stack when:

- the central stack is exposed **only by domain** (via Cloudflare Tunnel, etc.),
- the remote server has **no fixed public IP** (e.g. behind NAT), and
- access is protected by **Cloudflare Access service tokens**.

Tested on **Ubuntu 22.04 / 24.04**.

---

## 1. Architecture

```
+---------------------------+              +------------------------------+
|        REMOTE SERVER      |  HTTPS only  |       CENTRAL STACK          |
|  (no public IP, NAT'd)    |  ----------> |  exposed via Cloudflare      |
|                           |  CF Access   |  Tunnel on 3 hostnames:      |
|  node_exporter  :9100 (local)            |                              |
|        ^                  |              |  pulse.appwrk.com   Grafana  |
|        |                  |              |  stream.appwrk.com  Loki     |
|  prom-agent  --remote_write------------> |  metrics.appwrk.com Prom RW  |
|                                          |                              |
|  promtail  ----push logs--------------> |  stream.appwrk.com /loki/...  |
+---------------------------+              +------------------------------+
```

Three agents run as systemd services on every remote server:

| Component       | Purpose                                                  | Listens (local only) |
|-----------------|----------------------------------------------------------|----------------------|
| `node_exporter` | Exposes host CPU / memory / disk / network metrics       | `127.0.0.1:9100`     |
| `prom-agent`    | Prometheus in *agent mode* — scrapes node_exporter and `remote_write`s to central Prometheus | `127.0.0.1:9091` |
| `promtail`      | Tails log files and pushes them to Loki                  | `127.0.0.1:9080`     |

All three bind to **127.0.0.1 only**. They make **outbound HTTPS** calls to
the central domains — no inbound ports need to be opened on the remote.

---

## 2. Prerequisites (one-time, on the central stack side)

### 2.1 Expose Prometheus remote_write through a tunnel

The remote_write endpoint must be reachable from the internet. In Cloudflare
Tunnel, add a public hostname pointing to the in-cluster Prometheus service:

| Hostname                  | Service                                          |
|---------------------------|--------------------------------------------------|
| `pulse.appwrk.com`        | `http://grafana.monitoring.svc:3000`             |
| `stream.appwrk.com`       | `http://loki.monitoring.svc:3100`                |
| `metrics.appwrk.com`      | `http://prometheus.monitoring.svc:9090`          |

Then enable the remote_write receiver on central Prometheus.
[kubernetes/prometheus-deployment.yml](kubernetes/prometheus-deployment.yml)
already includes the flag:

```yaml
args:
  - '--web.enable-remote-write-receiver'
```

Apply / restart Prometheus:

```bash
kubectl apply -f kubernetes/prometheus-deployment.yml
kubectl rollout restart deployment/prometheus -n monitoring
```

### 2.2 Create a Cloudflare Access service token

1. Cloudflare Zero Trust dashboard → **Access → Service Auth → Service Tokens**.
2. Create a token (e.g. `monitoring-agent`). Cloudflare gives you a
   **Client ID** and **Client Secret** — copy them immediately, the secret is
   only shown once.
3. On the Access **applications** protecting `stream.appwrk.com` and
   `metrics.appwrk.com`, add a policy that allows this service token
   (Include → Service Auth → choose the token).

---

## 3. Install on a remote server

### 3.1 Copy the installer + env template

From your workstation:

```bash
scp scripts/setup-remote-server.sh user@remote:/tmp/
scp scripts/remote-agent.env.example user@remote:/tmp/
```

### 3.2 Place and protect the env file

On the remote server:

```bash
sudo mkdir -p /etc/monitoring-agent
sudo mv /tmp/remote-agent.env.example /etc/monitoring-agent/.env
sudo chmod 600 /etc/monitoring-agent/.env
sudo chown root:root /etc/monitoring-agent/.env
sudoedit /etc/monitoring-agent/.env   # fill in real values
```

Minimum fields to set:

```dotenv
SERVER_NAME=app-server-1
LOKI_PUSH_URL=https://stream.appwrk.com/loki/api/v1/push
PROM_REMOTE_WRITE_URL=https://metrics.appwrk.com/api/v1/write
CF_ACCESS_CLIENT_ID=<from Cloudflare>
CF_ACCESS_CLIENT_SECRET=<from Cloudflare>
```

> The `.env` file is the **only** place secrets live. It never enters git —
> `.env*` is in `.gitignore`. Only `remote-agent.env.example` (no secrets)
> is committed.

### 3.3 Run the installer

```bash
sudo bash /tmp/setup-remote-server.sh
```

The script will:

1. Install `node_exporter`, `promtail`, and `prom-agent` (Prometheus binary in agent mode).
2. Write systemd units that pull `CF_ACCESS_CLIENT_ID` / `CF_ACCESS_CLIENT_SECRET`
   from the env file at runtime via `EnvironmentFile=`. **The secrets never end up
   inside any config file on disk** — only the variable *names* are written there.
3. Enable and start all three services.

### 3.4 Verify locally

```bash
systemctl status node_exporter promtail prom-agent

# Each agent has a local readiness endpoint:
curl -s http://127.0.0.1:9100/metrics | head
curl -s http://127.0.0.1:9080/ready
curl -s http://127.0.0.1:9091/-/ready

# Check the outbound HTTPS calls are succeeding:
journalctl -u promtail   -n 50 --no-pager
journalctl -u prom-agent -n 50 --no-pager
```

### 3.5 Verify end-to-end (in Grafana)

| Check                           | Where                                                              |
|---------------------------------|--------------------------------------------------------------------|
| Logs reaching Loki              | Grafana → Explore → Loki → `{server="app-server-1"}`               |
| Metrics reaching Prometheus     | Grafana → Explore → Prometheus → `up{server="app-server-1"}`       |
| Or in the dashboards            | Open the Node Exporter dashboard, filter by `server`               |

You do **not** need to edit `prometheus.yml` to add a new scrape job — with
remote_write the metrics arrive labelled with `server=<SERVER_NAME>`.

---

## 4. Updating an existing remote server

To rotate the Cloudflare Access token or change endpoints:

```bash
sudoedit /etc/monitoring-agent/.env
sudo systemctl restart promtail prom-agent
```

To upgrade agent binaries, just re-run `setup-remote-server.sh`.

---

## 5. Uninstall

```bash
sudo systemctl disable --now node_exporter promtail prom-agent
sudo rm /etc/systemd/system/{node_exporter,promtail,prom-agent}.service
sudo rm -rf /etc/promtail /etc/prom-agent /var/lib/promtail /var/lib/prom-agent
sudo rm /usr/local/bin/{node_exporter,promtail,prom-agent}
sudo rm -rf /etc/monitoring-agent
sudo userdel node_exporter promtail prom_agent
sudo systemctl daemon-reload
```

---

## 6. Troubleshooting

- **Promtail logs `401 Unauthorized` or `403 Forbidden`**
  The Cloudflare Access policy on `stream.appwrk.com` is not allowing the
  service token. Re-check the policy includes Service Auth → your token.
- **`prom-agent` logs `remote_write: 403`**
  Same problem on the `metrics.appwrk.com` Access application.
- **`prom-agent` logs `remote_write: 405`**
  Central Prometheus is missing `--web.enable-remote-write-receiver`. See §2.1.
- **No logs in Grafana but Promtail looks healthy**
  Check `/var/lib/promtail/positions.yaml` is being updated, and that
  Promtail can read `/var/log/syslog` (it's added to the `adm` group by the
  installer).
- **Docker logs missing**
  The installer adds `promtail` to the `docker` group if it exists. If you
  install Docker after running the script, run
  `sudo usermod -aG docker promtail && sudo systemctl restart promtail`.
