#!/bin/bash
# Docker entrypoint script for Roger Dashboard

set -e

echo "🚀 Starting Roger Dashboard..."

# Initialize config from environment variables
if [ -z "$OLLAMA_HOST" ]; then
    export OLLAMA_HOST="http://ollama:11434"
    echo "⚙️  OLLAMA_HOST not set, using default: $OLLAMA_HOST"
fi

# Wait for Ollama to be ready if in Docker Compose
if [ "$OLLAMA_HOST" == "http://ollama:11434" ]; then
    echo "⏳ Waiting for Ollama service to be ready..."
    max_attempts=60
    attempt=0
    while ! curl -s "$OLLAMA_HOST/api/tags" > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            echo "❌ Ollama service did not start in time"
            exit 1
        fi
        echo "   Attempt $attempt/$max_attempts..."
        sleep 1
    done
    echo "✅ Ollama is ready!"
fi

# Start the application
echo "🎙️  Voice system: Piper TTS (en_US-ryan-high)"
echo "🧠 AI Provider: Ollama at $OLLAMA_HOST"
echo "📊 Dashboard: http://0.0.0.0:8020"
echo ""

exec python -m uvicorn src.main:app --host 0.0.0.0 --port 8020
