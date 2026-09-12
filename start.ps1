# PowerShell start script for MOSS-Transcribe-Diarize

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "          Starting MOSS-Transcribe-Diarize with Docker & GPU          " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check Docker command
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Docker CLI not found. Please install Docker Desktop." -ForegroundColor Red
    exit 1
}

# 2. Check if Docker daemon is running
$dockerRunning = $false
try {
    $null = docker ps 2>&1
    if ($LASTEXITCODE -eq 0) { $dockerRunning = $true }
} catch {
    $dockerRunning = $false
}

if (-not $dockerRunning) {
    Write-Host "[INFO] Docker daemon is not active. Attempting to start Docker Desktop..." -ForegroundColor Yellow
    if (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
        Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        Write-Host "[INFO] Waiting for Docker Desktop to complete startup (up to 45s)..." -ForegroundColor Yellow
        for ($i = 0; $i -lt 15; $i++) {
            Start-Sleep -Seconds 3
            $null = docker ps 2>&1
            if ($LASTEXITCODE -eq 0) {
                $dockerRunning = $true
                break
            }
        }
    }
}

if ($dockerRunning) {
    Write-Host "[OK] Docker daemon is connected and ready." -ForegroundColor Green
} else {
    Write-Host "[WARNING] Docker Desktop could not be automatically confirmed. Please make sure the Docker Desktop application window is open and showing green status." -ForegroundColor Yellow
}

# 3. Check NVIDIA GPU
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    Write-Host "[INFO] Local GPU info:" -ForegroundColor Cyan
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
} else {
    Write-Host "[WARNING] nvidia-smi not detected. The container will fall back to CPU unless NVIDIA drivers are active." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[INFO] Launching Docker Compose stack..." -ForegroundColor Green
Write-Host "[INFO] Local URL: http://localhost:7860" -ForegroundColor Green
Write-Host "[INFO] Public Cloudflare URL will appear below once the tunnel establishes." -ForegroundColor Green
Write-Host ""

docker compose up --build
