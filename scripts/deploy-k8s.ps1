# ==========================================
# KUBERNETES DEPLOYMENT SCRIPT (PowerShell)
# ==========================================
# This script deploys the monitoring stack to Kubernetes using NodePort

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Deploying Monitoring Stack to K8s" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check if kubectl is installed
try {
    $kubectlVersion = kubectl version --client 2>$null
    Write-Host "✅ kubectl found" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: kubectl is not installed!" -ForegroundColor Red
    exit 1
}

# Check if connected to cluster
try {
    $clusterInfo = kubectl cluster-info 2>$null
    $clusterName = kubectl config current-context 2>$null
    Write-Host "✅ Connected to Kubernetes cluster" -ForegroundColor Green
    Write-Host "📍 Current cluster: $clusterName" -ForegroundColor Yellow
} catch {
    Write-Host "❌ Error: Not connected to Kubernetes cluster!" -ForegroundColor Red
    Write-Host "Please configure kubectl first" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Create namespace
Write-Host "📁 Creating monitoring namespace..." -ForegroundColor Cyan
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
Write-Host "✅ Namespace ready" -ForegroundColor Green
Write-Host ""

# Deploy Loki
Write-Host "🚀 Deploying Loki..." -ForegroundColor Cyan
kubectl apply -f kubernetes/loki-deployment.yml
Write-Host "✅ Loki deployed" -ForegroundColor Green
Write-Host ""

# Wait for Loki to be ready
Write-Host "⏳ Waiting for Loki to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=300s 2>$null
Write-Host "✅ Loki is ready" -ForegroundColor Green
Write-Host ""

# Deploy Prometheus
Write-Host "🚀 Deploying Prometheus..." -ForegroundColor Cyan
kubectl apply -f kubernetes/prometheus-deployment.yml
Write-Host "✅ Prometheus deployed" -ForegroundColor Green
Write-Host ""

# Deploy Alertmanager
Write-Host "🚀 Deploying Alertmanager..." -ForegroundColor Cyan
kubectl apply -f kubernetes/alertmanager-deployment.yml
Write-Host "✅ Alertmanager deployed" -ForegroundColor Green
Write-Host ""

# Wait for Prometheus to be ready
Write-Host "⏳ Waiting for Prometheus to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s 2>$null
Write-Host "✅ Prometheus is ready" -ForegroundColor Green
Write-Host ""

# Wait for Alertmanager to be ready
Write-Host "⏳ Waiting for Alertmanager to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=alertmanager -n monitoring --timeout=300s 2>$null
Write-Host "✅ Alertmanager is ready" -ForegroundColor Green
Write-Host ""

# Deploy Grafana
Write-Host "🚀 Deploying Grafana..." -ForegroundColor Cyan
kubectl apply -f kubernetes/grafana-deployment.yml
Write-Host "✅ Grafana deployed" -ForegroundColor Green
Write-Host ""

# Wait for Grafana to be ready
Write-Host "⏳ Waiting for Grafana to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s 2>$null
Write-Host "✅ Grafana is ready" -ForegroundColor Green
Write-Host ""

# Get service information
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "✅ Monitoring Stack Deployed!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📊 Service Status:" -ForegroundColor Cyan
kubectl get svc -n monitoring
Write-Host ""

# Get NodePort information
$grafanaPort = kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>$null
$prometheusPort = kubectl get svc prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}' 2>$null

Write-Host "🔗 Access URLs (using NodePort):" -ForegroundColor Cyan
Write-Host "  Grafana:    http://localhost:$grafanaPort (admin / admin123)" -ForegroundColor Yellow
Write-Host "  Prometheus: http://localhost:$prometheusPort" -ForegroundColor Yellow
Write-Host "  Loki:       via Grafana datasource" -ForegroundColor Yellow
Write-Host ""

Write-Host "📋 Useful Commands:" -ForegroundColor Cyan
Write-Host "  View pods:       kubectl get pods -n monitoring" -ForegroundColor Yellow
Write-Host "  View logs:       kubectl logs -n monitoring -l app=grafana" -ForegroundColor Yellow
Write-Host "  Port forward:    kubectl port-forward svc/grafana 3000:3000 -n monitoring" -ForegroundColor Yellow
Write-Host "  Delete stack:    kubectl delete namespace monitoring" -ForegroundColor Yellow
Write-Host ""
