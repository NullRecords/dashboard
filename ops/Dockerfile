FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies including voice system requirements
RUN apt-get update && apt-get install -y \
    gcc \
    git \
    curl \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Download and install Piper TTS
RUN mkdir -p /app/data/voice_models/piper && \
    cd /tmp && \
    curl -L "https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz" -o piper.tar.gz && \
    tar -xzf piper.tar.gz -C /app/data/voice_models/piper --strip-components=1 && \
    chmod +x /app/data/voice_models/piper/piper && \
    rm piper.tar.gz

# Download Piper voice model (en_US-ryan-high for Roger)
RUN curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx" \
    -o /app/data/voice_models/piper/en_US-ryan-high.onnx && \
    curl -L "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx.json" \
    -o /app/data/voice_models/piper/en_US-ryan-high.onnx.json

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy all necessary application files and directories
COPY src/ ./src/
COPY static/ ./static/
COPY assets/ ./assets/
COPY collectors/ ./collectors/
COPY scripts/ ./scripts/
COPY config/ ./config/
COPY database.py ./
COPY splash.html ./
COPY ops/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

# Create necessary directories
RUN mkdir -p /app/tokens /app/data /app/logs /app/data/voice_cache

# Expose port
EXPOSE 8008

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8008/health || exit 1

# Run using entrypoint script
ENTRYPOINT ["./entrypoint.sh"]