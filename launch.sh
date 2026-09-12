#!/bin/sh
set -e

echo "========================================================"
echo "          Launching MOSS-Transcribe-Diarize Containers  "
echo "========================================================"

# Remove existing containers if any
docker rm -f moss-transcribe-diarize moss-cloudflare-tunnel 2>/dev/null || true

# Test if GPU passthrough is supported
GPU_FLAG=""
if docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
    echo "[INFO] NVIDIA GPU support confirmed for Docker."
    GPU_FLAG="--gpus all"
else
    echo "[INFO] Running with standard container runtime."
fi

# Run MOSS Subtitle Web App
echo "[INFO] Starting moss-transcribe-diarize container on port 7860..."
docker run -d \
  --name moss-transcribe-diarize \
  --restart unless-stopped \
  -p 7860:7860 \
  -v "/mnt/c/Jason Antigravity/Moss Transcribe Diarize/hf_cache:/root/.cache/huggingface" \
  -v "/mnt/c/Jason Antigravity/Moss Transcribe Diarize/runs:/app/runs" \
  $GPU_FLAG \
  moss-transcribe-diarize:latest

echo "[INFO] Starting cloudflared tunnel container..."
docker run -d \
  --name moss-cloudflare-tunnel \
  --restart unless-stopped \
  --network host \
  cloudflare/cloudflared:latest tunnel --no-autoupdate --url http://127.0.0.1:7860

echo ""
echo "[SUCCESS] Containers launched!"
echo "Local Web UI: http://localhost:7860"
echo "Cloudflare Tunnel URL fetching in progress..."
sleep 5
docker logs moss-cloudflare-tunnel 2>&1 | grep -o 'https://.*\.trycloudflare\.com' | tail -n 1 || true
