#!/bin/bash
# ==========================================
# DOCKER DEPLOYMENT SCRIPT
# ==========================================
# This script deploys the monitoring stack using Docker Compose

set -e

echo "======================================"
echo "Starting Monitoring Stack with Docker"
echo "======================================"

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create .env file from .env.example:"
    echo "  cp .env.example .env"
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '#' | xargs)

echo "✅ Loading environment variables from .env"

# Create necessary directories
echo "📁 Creating required directories..."
mkdir -p grafana_storage
mkdir -p loki_storage
mkdir -p prometheus_storage
mkdir -p grafana-provisioning/datasources
mkdir -p grafana-provisioning/dashboards

# Check if Docker is running
echo "🐳 Checking Docker daemon..."
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running!"
    exit 1
fi

echo "✅ Docker is running"

# Build and start containers
echo "🚀 Starting containers..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check service health
echo "🔍 Checking service health..."

# Check Loki
if docker ps | grep loki > /dev/null; then
    echo "✅ Loki is running"
else
    echo "❌ Loki failed to start"
    docker-compose logs loki
    exit 1
fi

# Check Grafana
if docker ps | grep grafana > /dev/null; then
    echo "✅ Grafana is running"
else
    echo "❌ Grafana failed to start"
    docker-compose logs grafana
    exit 1
fi

# Check Prometheus
if docker ps | grep prometheus > /dev/null; then
    echo "✅ Prometheus is running"
else
    echo "❌ Prometheus failed to start"
    docker-compose logs prometheus
    exit 1
fi

# Display connection information
echo ""
echo "======================================"
echo "✅ Monitoring Stack is Ready!"
echo "======================================"
echo ""
echo "📊 Access URLs:"
echo "  Grafana:    http://localhost:${GRAFANA_PORT} (admin / admin123)"
echo "  Prometheus: http://localhost:${PROMETHEUS_PORT}"
echo "  Loki:       http://localhost:${LOKI_PORT}"
echo ""
echo "📝 Next Steps:"
echo "  1. Open Grafana: http://localhost:${GRAFANA_PORT}"
echo "  2. Add Loki datasource: http://loki:3100"
echo "  3. Create dashboards"
echo ""
echo "🛑 To stop the stack:"
echo "  docker-compose down"
echo ""
echo "📋 To view logs:"
echo "  docker-compose logs -f [service_name]"
echo ""
