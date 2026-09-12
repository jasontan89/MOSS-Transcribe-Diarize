#!/bin/sh
set -e
cd "/mnt/c/Jason Antigravity/Moss Transcribe Diarize"
echo "[BUILD] Starting Docker build for MOSS-Transcribe-Diarize..."
docker build -t moss-transcribe-diarize:latest -f Dockerfile .
echo "[BUILD] Image built successfully!"
