# Remote Server Setup Guide (Windows)

If your remote server is running **Windows**, follow this guide to set up monitoring.

## Setup on Windows Server

### Step 1: Install Nssm (Non-Sucking Service Manager)

Nssm allows running executables as services:

```powershell
# Download and extract nssm
$nssm_url = "https://nssm.cc/download/nssm-2.24.zip"
$output = "$env:TEMP\nssm-2.24.zip"
Invoke-WebRequest -Uri $nssm_url -OutFile $output
Expand-Archive -Path $output -DestinationPath "C:\nssm"

# Add to PATH
$env:Path += ";C:\nssm\nssm-2.24\win64"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)
```

### Step 2: Install Node Exporter

```powershell
# Create directory
New-Item -ItemType Directory -Force -Path "C:\Program Files\node_exporter"

# Download Node Exporter
$url = "https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.msi"
$output = "$env:TEMP\node_exporter-1.7.0.msi"
Invoke-WebRequest -Uri $url -OutFile $output

# Install MSI
Start-Process msiexec.exe -ArgumentList "/i $output" -Wait -NoNewWindow
```

Or use Chocolatey:

```powershell
choco install prometheus-node-exporter -y
```

### Step 3: Install Promtail

```powershell
# Create directory
New-Item -ItemType Directory -Force -Path "C:\Program Files\Promtail"

# Download Promtail
$url = "https://github.com/grafana/loki/releases/download/v2.9.0/promtail-windows-amd64.exe"
$output = "C:\Program Files\Promtail\promtail.exe"
Invoke-WebRequest -Uri $url -OutFile $output

# Make it executable
attrib +x "$output"
```

### Step 4: Create Promtail Configuration

Create `C:\Program Files\Promtail\config.yml`:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: C:\Promtail\positions.yaml

clients:
  - url: http://<LOKI_CENTRAL_IP>:3100/loki/api/v1/push
    tenant_id: production

scrape_configs:
  # Windows Event Logs
  - job_name: windows_events
    static_configs:
      - targets:
          - localhost
        labels:
          job: windows
          server: '<SERVER_NAME>'
          channel: Application

  # Application Logs
  - job_name: app_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: application
          server: '<SERVER_NAME>'
          __path__: 'C:\Logs\*.log'

  # IIS Logs (if running IIS)
  - job_name: iis_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: iis
          server: '<SERVER_NAME>'
          __path__: 'C:\inetpub\logs\LogFiles\*\*.log'
```

Replace:
- `<LOKI_CENTRAL_IP>` - Your central monitoring server IP
- `<SERVER_NAME>` - Name of this server
- Log paths - Adjust to your application paths

### Step 5: Register Services

#### Node Exporter Service:

```powershell
nssm install "node_exporter" "C:\Program Files\Prometheus-Node-Exporter\node_exporter.exe"
nssm start "node_exporter"
```

#### Promtail Service:

```powershell
# Create data directory
New-Item -ItemType Directory -Force -Path "C:\Promtail"

# Install service
nssm install "promtail" "C:\Program Files\Promtail\promtail.exe" "-config.file=C:\Program Files\Promtail\config.yml"

# Start service
nssm start "promtail"
```

### Step 6: Verify Installation

```powershell
# Check services
Get-Service | Where-Object {$_.Name -match "promtail|node_exporter"}

# Check Node Exporter metrics
Invoke-WebRequest -Uri "http://localhost:9100/metrics" | Select-Object Content

# Check Promtail HTTP
Invoke-WebRequest -Uri "http://localhost:9080" | Select-Object StatusCode
```

### Step 7: Update Central Prometheus Config

On your central monitoring server, update `prometheus.yml`:

```yaml
- job_name: 'windows-server'
  static_configs:
    - targets: ['<WINDOWS_SERVER_IP>:9100']
      labels:
        server_name: 'windows-prod'
        os: 'windows'
```

Restart Prometheus.

## Collecting Different Log Types

### Option 1: Windows Event Logs

Use a separate tool like [Event Log to Syslog](https://github.com/microsoft/Windows-Event-Log-to-Syslog) or [Winlogbeat](https://www.elastic.co/beats/winlogbeat).

### Option 2: Application Logs from Files

Create a scheduled task to tail your application logs:

```powershell
# Create a PowerShell script: tail-logs.ps1
Get-Content -Path "C:\Logs\app.log" -Tail 100 -Wait | ForEach-Object {
    # Send to Promtail
    Invoke-RestMethod -Uri "http://localhost:9080" -Method Post -Body $_
}
```

### Option 3: Docker Container Logs (on Windows)

If running Docker on Windows:

```yaml
- job_name: docker_logs
  static_configs:
    - targets:
        - localhost
      labels:
        job: docker
        server: '<SERVER_NAME>'
        __path__: 'C:\ProgramData\Docker\containers\*\*-json.log'
```

## Troubleshooting Windows

### Service won't start

```powershell
# Check service status
nssm status promtail

# View service logs
nssm status promtail
nssm edit promtail  # Edit service configuration

# Check error logs
Get-EventLog -LogName Application -Source promtail -After (Get-Date).AddHours(-1)
```

### Firewall blocking ports

```powershell
# Open port 9100 (Node Exporter)
New-NetFirewallRule -DisplayName "Node Exporter" `
  -Direction Inbound `
  -LocalPort 9100 `
  -Protocol TCP `
  -Action Allow

# Open port 9080 (Promtail)
New-NetFirewallRule -DisplayName "Promtail" `
  -Direction Inbound `
  -LocalPort 9080 `
  -Protocol TCP `
  -Action Allow
```

### Logs not being sent

```powershell
# Check Promtail is running
Get-Service -Name promtail -ErrorAction SilentlyContinue

# Check configuration
Get-Content "C:\Program Files\Promtail\config.yml"

# Manually test Loki connection
$params = @{
    Uri = "http://<LOKI_IP>:3100/ready"
    Method = "Get"
}
Invoke-RestMethod @params
```

## Uninstall Services

```powershell
# Stop services
nssm stop promtail
nssm stop node_exporter

# Remove services
nssm remove promtail confirm
nssm remove node_exporter confirm
```

## Performance Considerations

### Reduce CPU Usage

```yaml
# In Promtail config, increase skip frequency
scrape_configs:
  - job_name: app_logs
    skip_log_entries: 10  # Skip every 10th entry
```

### Reduce Memory Usage

```yaml
# Limit batch size in Promtail
clients:
  - max_entries_limit_per_second: 10000
    batch_size_bytes: 1000000
```

---

**Windows servers are now set up for monitoring!** 🎉
