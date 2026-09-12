# Base image: Official PyTorch runtime with CUDA 12.4 and cuDNN 9
FROM pytorch/pytorch:2.5.1-cuda12.4-cudnn9-runtime

# Environment settings
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/root/.cache/huggingface \
    TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;8.9;9.0"

WORKDIR /app

# Install system audio libraries, ffmpeg and git
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libsndfile1 \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy pyproject.toml first to leverage Docker layer caching
COPY pyproject.toml /app/

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
        "transformers>=4.48.0" \
        "safetensors>=0.4.5" \
        "numpy>=1.26,<3" \
        "av>=14.0" \
        "librosa>=0.10.0" \
        "numba>=0.60.0" \
        "soundfile>=0.12" \
        "soxr>=0.5" \
        "packaging" \
        "fastapi>=0.115" \
        "uvicorn>=0.30" \
        "python-multipart>=0.0.9"

# Copy source code and assets
COPY moss_transcribe_diarize /app/moss_transcribe_diarize
COPY README.md LICENSE /app/

# Install the moss_transcribe_diarize package
RUN pip install --no-cache-dir -e .

# Expose web port
EXPOSE 7860

# Default entrypoint runs the subtitle web server
ENTRYPOINT ["mtd-subtitle-web"]
CMD ["--host", "0.0.0.0", "--port", "7860", "--model", "OpenMOSS-Team/MOSS-Transcribe-Diarize", "--device", "cuda", "--dtype", "bf16"]
