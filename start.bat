@echo off
setlocal enabledelayedexpansion

echo ======================================================================
echo           Starting MOSS-Transcribe-Diarize with Docker & GPU
echo ======================================================================
echo.

:: 1. Check if Docker is installed
where docker >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Docker is not found on your PATH.
    echo Please install or enable Docker Desktop: https://www.docker.com/products/docker-desktop/
    pause
    exit /b 1
)

:: 2. Check if Docker daemon is running
docker ps >nul 2>nul
if %errorlevel% neq 0 (
    echo [INFO] Docker daemon is not responding yet.
    echo Starting Docker Desktop...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo Waiting for Docker Desktop engine to initialize (up to 40 seconds)...
    
    set /a count=0
    :wait_docker
    timeout /t 3 /nobreak >nul
    docker ps >nul 2>nul
    if %errorlevel% equ 0 goto docker_ready
    set /a count+=3
    if !count! lss 45 goto wait_docker

    echo [WARNING] Docker Desktop is still initializing. Please ensure Docker Desktop is open.
)

:docker_ready
echo [OK] Docker daemon is running!
echo.

:: 3. Check NVIDIA GPU availability
where nvidia-smi >nul 2>nul
if %errorlevel% equ 0 (
    echo [INFO] Detected NVIDIA GPU:
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
) else (
    echo [WARNING] nvidia-smi not found. GPU acceleration might not be active.
)
echo.

:: 4. Build and run containers
echo [INFO] Starting MOSS-Transcribe-Diarize + Cloudflare Tunnel...
echo Local Web UI will be accessible at: http://localhost:7860
echo.
docker compose up --build

pause
