# Lean Docker image for Personal Dashboard
# Multi-stage build for smaller final image

# ============================================
# Stage 1: Download voice models
# ============================================
FROM alpine:3.19 AS voice-downloader

RUN apk add --no-cache curl tar

WORKDIR /downloads

# Download Piper TTS binary
RUN curl -L "https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz" -o piper.tar.gz && \
    mkdir piper && \
    tar -xzf piper.tar.gz -C piper --strip-components=1 && \
    rm piper.tar.gz

# Download voice model
RUN curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx" \
    -o piper/en_US-ryan-high.onnx && \
    curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx.json" \
    -o piper/en_US-ryan-high.onnx.json

# ============================================
# Stage 2: Build Python dependencies
# ============================================
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements-docker.txt .
RUN pip install --no-cache-dir --user -r requirements-docker.txt

# ============================================
# Stage 3: Final lean image
# ============================================
FROM python:3.11-slim

WORKDIR /app

# Install only runtime dependencies (no build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ffmpeg \
    cron \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# Copy voice models from downloader
COPY --from=voice-downloader /downloads/piper /app/data/voice_models/piper
RUN chmod +x /app/data/voice_models/piper/piper

# Copy application code
COPY src/ ./src/
COPY static/ ./static/
COPY assets/ ./assets/
COPY collectors/ ./collectors/
COPY scripts/ ./scripts/
COPY config/ ./config/
COPY data/skins/ ./data/skins/
COPY database.py ./
COPY splash.html ./
COPY ops/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

# Create necessary directories
RUN mkdir -p /app/tokens /app/data /app/logs /app/data/voice_cache

# Expose port
EXPOSE 8020

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8020/health || exit 1

ENTRYPOINT ["./entrypoint.sh"]
