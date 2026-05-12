#!/bin/bash
# ==========================================
# KUBERNETES DEPLOYMENT SCRIPT
# ==========================================
# This script deploys the monitoring stack to Kubernetes using NodePort

set -e

echo "======================================"
echo "Deploying Monitoring Stack to K8s"
echo "======================================"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed!"
    exit 1
fi

echo "✅ kubectl found"

# Check if connected to cluster
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "❌ Error: Not connected to Kubernetes cluster!"
    echo "Please configure kubectl first"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"

# Get cluster info
CLUSTER_NAME=$(kubectl config current-context)
echo "📍 Current cluster: $CLUSTER_NAME"
echo ""

# Create namespace
echo "📁 Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready"
echo ""

# Deploy Loki
echo "🚀 Deploying Loki..."
kubectl apply -f kubernetes/loki-deployment.yml
echo "✅ Loki deployed"
echo ""

# Wait for Loki to be ready
echo "⏳ Waiting for Loki to be ready..."
kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=300s || true
echo "✅ Loki is ready"
echo ""

# Deploy Prometheus
echo "🚀 Deploying Prometheus..."
kubectl apply -f kubernetes/prometheus-deployment.yml
echo "✅ Prometheus deployed"
echo ""

# Deploy Alertmanager
echo "🚀 Deploying Alertmanager..."
kubectl apply -f kubernetes/alertmanager-deployment.yml
echo "✅ Alertmanager deployed"
echo ""

# Wait for Prometheus to be ready
echo "⏳ Waiting for Prometheus to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s || true
echo "✅ Prometheus is ready"
echo ""

# Wait for Alertmanager to be ready
echo "⏳ Waiting for Alertmanager to be ready..."
kubectl wait --for=condition=ready pod -l app=alertmanager -n monitoring --timeout=300s || true
echo "✅ Alertmanager is ready"
echo ""

# Deploy Grafana
echo "🚀 Deploying Grafana..."
kubectl apply -f kubernetes/grafana-deployment.yml
echo "✅ Grafana deployed"
echo ""

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s || true
echo "✅ Grafana is ready"
echo ""

# Get service information
echo "======================================"
echo "✅ Monitoring Stack Deployed!"
echo "======================================"
echo ""
echo "📊 Service Status:"
kubectl get svc -n monitoring
echo ""

# Get NodePort information
GRAFANA_PORT=$(kubectl get svc grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
PROMETHEUS_PORT=$(kubectl get svc prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
LOKI_PORT=$(kubectl get svc loki -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
ALERTMANAGER_PORT=$(kubectl get svc alertmanager -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "🔗 Access URLs (using NodePort, node IP: $NODE_IP):"
echo "  Grafana:      http://$NODE_IP:$GRAFANA_PORT (admin / admin123)"
echo "  Prometheus:   http://$NODE_IP:$PROMETHEUS_PORT"
echo "  Loki push:    http://$NODE_IP:$LOKI_PORT/loki/api/v1/push"
echo "  Alertmanager: http://$NODE_IP:$ALERTMANAGER_PORT"
echo ""

echo "📋 Useful Commands:"
echo "  View pods:       kubectl get pods -n monitoring"
echo "  View logs:       kubectl logs -n monitoring -l app=grafana"
echo "  Port forward:    kubectl port-forward svc/grafana 3000:3000 -n monitoring"
echo "  Delete stack:    kubectl delete namespace monitoring"
echo ""
