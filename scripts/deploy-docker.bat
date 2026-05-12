@echo off
REM ==========================================
REM DOCKER DEPLOYMENT SCRIPT (Windows)
REM ==========================================
REM This script deploys the monitoring stack using Docker Compose on Windows

setlocal enabledelayedexpansion

echo.
echo ======================================
echo Starting Monitoring Stack with Docker
echo ======================================
echo.

REM Check if .env file exists
if not exist .env (
    echo Error: .env file not found!
    echo Please create .env file from .env.example:
    echo   copy .env.example .env
    pause
    exit /b 1
)

echo [OK] Found .env file
echo.

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo Error: Docker is not running!
    pause
    exit /b 1
)

echo [OK] Docker is running
echo.

REM Create necessary directories
echo Creating required directories...
if not exist grafana_storage mkdir grafana_storage
if not exist loki_storage mkdir loki_storage
if not exist prometheus_storage mkdir prometheus_storage
if not exist grafana-provisioning\datasources mkdir grafana-provisioning\datasources
if not exist grafana-provisioning\dashboards mkdir grafana-provisioning\dashboards

echo [OK] Directories created
echo.

REM Start containers
echo Pulling latest images and starting containers...
docker-compose up -d

if errorlevel 1 (
    echo Error: Failed to start containers
    pause
    exit /b 1
)

echo.
echo ======================================
echo Monitoring Stack is Starting!
echo ======================================
echo.

REM Wait for services
echo Waiting for services to be ready...
timeout /t 10 /nobreak

echo.
echo ======================================
echo Monitoring Stack is Ready!
echo ======================================
echo.
echo Access URLs:
echo   Grafana:    http://localhost:3000 (admin / admin123)
echo   Prometheus: http://localhost:9090
echo   Loki:       http://localhost:3100
echo.
echo To stop the stack:
echo   docker-compose down
echo.
echo To view logs:
echo   docker-compose logs -f [service_name]
echo.
pause
