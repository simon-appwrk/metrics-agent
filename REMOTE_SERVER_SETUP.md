# Remote Server Setup — Metrics & Logs (domain + HTTP Basic Auth)

Ship **logs** and **metrics** from any remote server to your central
Loki + Prometheus + Grafana stack when:

- the central stack is exposed **only by domain** (Cloudflare Tunnel, etc.),
- the remote server has **no fixed public IP** (e.g. behind NAT), and
- you don't have a Cloudflare Zero Trust plan (so Access Applications and
  Service Tokens aren't usable for gating the tunnel hostnames).

Auth is enforced by a small **nginx auth-proxy** running inside the cluster
that checks HTTP Basic Auth on every request before forwarding to Loki /
Prometheus. The tunnel itself just transports traffic.

Tested on **Ubuntu 22.04 / 24.04**.

---

## 1. Architecture

```
+---------------------------+              +-----------------------------------+
|        REMOTE SERVER      |   HTTPS +    |          CENTRAL STACK            |
|  (no public IP, NAT'd)    |  Basic Auth  |  exposed via Cloudflare Tunnel    |
|                           |  ─────────►  |                                   |
|  node_exporter  :9100     |              |    auth-proxy (nginx, in-cluster) |
|        ▲                  |              |     ├─ stream.appwrk.com → loki   |
|  prom-agent  ──remote_write────────────► |     └─ metrics.appwrk.com → prom  |
|                                          |              ▲                    |
|  promtail  ──push logs───────────────►   |     pulse.appwrk.com → grafana    |
|                                          |     (no auth-proxy: Grafana has   |
|                                          |      its own login)               |
+---------------------------+              +-----------------------------------+
```

Three agents run as systemd services on every remote server:

| Component       | Purpose                                                  | Listens (local only) |
|-----------------|----------------------------------------------------------|----------------------|
| `node_exporter` | Exposes host CPU / memory / disk / network metrics       | `127.0.0.1:9100`     |
| `prom-agent`    | Prometheus in *agent mode* — scrapes node_exporter and `remote_write`s to central Prometheus | `127.0.0.1:9091` |
| `promtail`      | Tails log files and pushes them to Loki                  | `127.0.0.1:9080`     |

All three bind to **127.0.0.1 only**. They make **outbound HTTPS** calls —
no inbound ports need to be opened on the remote.

---

## 2. Central-side setup (one time)

### 2.1 Enable Prometheus remote_write receiver

[kubernetes/prometheus-deployment.yml](kubernetes/prometheus-deployment.yml)
already includes `--web.enable-remote-write-receiver`. Apply / restart:

```bash
kubectl apply -f kubernetes/prometheus-deployment.yml
kubectl rollout restart deployment/prometheus -n monitoring
```

### 2.2 Create the Basic Auth secret

Pick a strong password (this is the "token" remote agents will use):

```bash
bash scripts/create-auth-secret.sh monitoring 'pick-a-strong-password-here'
```

The script generates a SHA-512-crypt hash, stores it in the Kubernetes Secret
`auth-proxy-htpasswd`, and the plaintext password is never written to disk
on the central side after this.

> Keep the plaintext password handy — you'll paste it into the remote `.env`.
> Lose it and you must rotate (re-run the script with a new password and
> update every remote `.env`).

### 2.3 Deploy the nginx auth-proxy

```bash
kubectl apply -f kubernetes/auth-proxy-deployment.yml
kubectl -n monitoring rollout status deploy/auth-proxy
```

This stands up nginx on NodePort `30340`. It listens on `:8080` with two
virtual hosts:

| Host header             | Forwards to        | Auth                  |
|-------------------------|--------------------|-----------------------|
| `stream.appwrk.com`     | `loki:3100`        | Basic Auth (htpasswd) |
| `metrics.appwrk.com`    | `prometheus:9090`  | Basic Auth (htpasswd) |
| anything else           | 444 (close conn)   | —                     |

The health paths `/ready` (Loki) and `/-/ready` (Prometheus) are left open
so tunnel and uptime checks work without auth.

### 2.4 Reconfigure Cloudflare Tunnel

In the tunnel dashboard, **change the origins** of the public hostnames so
they go through the auth-proxy instead of directly to Loki/Prometheus:

| Public hostname         | Type | URL                                          |
|-------------------------|------|----------------------------------------------|
| `stream.appwrk.com`     | HTTP | `localhost:30340`  (was `localhost:30320`)   |
| `metrics.appwrk.com`    | HTTP | `localhost:30340`  *(create this hostname if it doesn't exist)* |
| `pulse.appwrk.com`      | HTTP | `localhost:30300`  *(unchanged — Grafana)*   |

Save. The tunnel reroutes within a few seconds.

> Both stream and metrics point to the **same** NodePort. The auth-proxy
> uses the `Host` header (which Cloudflare Tunnel passes through unchanged)
> to decide whether to forward to Loki or Prometheus.

### 2.5 Verify auth-proxy enforcement

From your laptop, no creds — should be 401:

```bash
curl -i https://stream.appwrk.com/loki/api/v1/labels
# expect: HTTP 401 Unauthorized

curl -i https://metrics.appwrk.com/api/v1/status/runtimeinfo
# expect: HTTP 401 Unauthorized
```

With creds — should succeed:

```bash
curl -i -u monitoring:'<password>' https://stream.appwrk.com/loki/api/v1/labels
# expect: HTTP 200 with JSON
```

Health checks remain open (used by the tunnel itself):

```bash
curl -s https://stream.appwrk.com/ready          # → "ready"
curl -s https://metrics.appwrk.com/-/ready       # → "Prometheus Server is Ready."
```

---

## 3. Install on a remote server

### 3.1 Copy the installer + env template

From your workstation:

```bash
scp scripts/setup-remote-server.sh scripts/remote-agent.env.example user@remote:/tmp/
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

Minimum fields:

```dotenv
SERVER_NAME=app-server-1
LOKI_PUSH_URL=https://stream.appwrk.com/loki/api/v1/push
PROM_REMOTE_WRITE_URL=https://metrics.appwrk.com/api/v1/write
AUTH_USERNAME=monitoring
AUTH_PASSWORD=<the password from step 2.2>
```

> The `.env` is the **only** place credentials live. It never enters git —
> `.env*` is in `.gitignore`. Only `remote-agent.env.example` (no secrets)
> is committed.

### 3.3 Run the installer

```bash
sudo bash /tmp/setup-remote-server.sh
```

The script:

1. Installs `node_exporter`, `promtail`, and `prom-agent` (Prometheus binary in agent mode).
2. Writes systemd units that pull `AUTH_USERNAME` / `AUTH_PASSWORD` from the
   env file at runtime via `EnvironmentFile=`. For Promtail the password is
   expanded via `-config.expand-env=true`; for prom-agent it's written to a
   `0600` `password_file` (Prometheus does not expand env vars in basic_auth).
   **The password never lives in YAML on disk.**
3. Enables and starts all three services.

### 3.4 Verify locally

```bash
systemctl status node_exporter promtail prom-agent

curl -s http://127.0.0.1:9100/metrics | head
curl -s http://127.0.0.1:9080/ready
curl -s http://127.0.0.1:9091/-/ready

# Look for outbound errors. 401 means wrong AUTH_*; 404/405 means wrong URL.
journalctl -u promtail   -n 50 --no-pager
journalctl -u prom-agent -n 50 --no-pager
```

### 3.5 Verify end-to-end in Grafana

| Check                       | Where                                                          |
|-----------------------------|----------------------------------------------------------------|
| Logs reaching Loki          | Grafana → Explore → Loki → `{server="app-server-1"}`           |
| Metrics reaching Prometheus | Grafana → Explore → Prometheus → `up{server="app-server-1"}`   |
| Dashboards                  | Open the Node Exporter dashboard, filter by `server`           |

You do **not** need to edit `prometheus.yml` to add a new scrape job — with
remote_write the metrics arrive already labelled with `server=<SERVER_NAME>`.

---

## 4. Rotate the password

```bash
# 1. central side — new password
bash scripts/create-auth-secret.sh monitoring '<new-strong-password>'
kubectl -n monitoring rollout restart deploy/auth-proxy

# 2. each remote — update .env and restart
sudoedit /etc/monitoring-agent/.env
sudo systemctl restart promtail prom-agent
```

A short window of 401s on remotes is expected between step 1 and step 2 —
Promtail and prom-agent both buffer and retry, so no data is lost.

---

## 5. Uninstall (remote)

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

- **Promtail / prom-agent logs `401 Unauthorized`**
  Wrong `AUTH_USERNAME` or `AUTH_PASSWORD` in `/etc/monitoring-agent/.env`,
  or the central htpasswd Secret has a different password. Re-run
  `scripts/create-auth-secret.sh` and update the remote `.env`.

- **prom-agent logs `remote_write: 405 Method Not Allowed`**
  Central Prometheus is missing `--web.enable-remote-write-receiver`.
  See §2.1.

- **Browser to `https://stream.appwrk.com/loki/api/v1/labels` returns 200 without creds**
  The tunnel is still routing to Loki directly, not to the auth-proxy.
  Re-check the tunnel hostname URL points at `localhost:30340`, not `:30320`.

- **`curl ... https://stream.appwrk.com/ready` returns `ready` without auth**
  This is intentional — the health probe is left open. Auth is enforced on
  every other path (`/loki/api/v1/*`).

- **No logs in Grafana but Promtail looks healthy**
  Check `/var/lib/promtail/positions.yaml` is updating and Promtail can
  read `/var/log/syslog` (it's added to the `adm` group by the installer).

- **Docker logs missing**
  The installer adds `promtail` to the `docker` group if it exists. If
  Docker was installed later, run
  `sudo usermod -aG docker promtail && sudo systemctl restart promtail`.
