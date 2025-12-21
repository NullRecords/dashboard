# 🐳 Docker Quick Start - Roger Dashboard

Run the entire Parker Dashboard (with Roger Assistant, voice, and local AI) in Docker containers. Everything you need is pre-configured and automatically installed.

## Prerequisites

- Docker Desktop (Windows/Mac) or Docker Engine (Linux)
- Docker Compose (usually included with Docker Desktop)
- 10 GB disk space (for Ollama tinyllama model)

## Quick Start (30 seconds)

### 1. Start Everything

```bash
cd /path/to/dashboard
docker-compose -f ops/docker-compose.yml up -d
```

### 2. Wait for Models to Download

First run takes ~2-3 minutes:
- Ollama downloads tinyllama AI model (~7GB)
- Piper voice model pre-installed in container

Check progress:
```bash
docker-compose -f ops/docker-compose.yml logs -f ollama
```

### 3. Open Dashboard

**http://localhost:8008**

✅ Roger Assistant with voice ready
✅ Local AI (tinyllama - no API key needed)
✅ Star Wars backgrounds
✅ Jokes system
✅ All features working

## What's Included

**🐳 Pre-installed in Docker:**
- ✅ Python 3.11 + all dependencies
- ✅ Piper TTS (en_US-ryan-high voice model) - 116MB
- ✅ ffmpeg for voice effects
- ✅ Roger Assistant fully configured
- ✅ Voice cache directory

**🤖 Automatic Setup:**
- ✅ Ollama service with tinyllama model
- ✅ Voice system ready immediately
- ✅ No manual configuration needed

## Commands

### Start
```bash
docker-compose -f ops/docker-compose.yml up -d
```

### Check Status
```bash
docker-compose -f ops/docker-compose.yml ps
docker-compose -f ops/docker-compose.yml logs -f dashboard
```

### Stop
```bash
docker-compose -f ops/docker-compose.yml down
```

### Restart
```bash
docker-compose -f ops/docker-compose.yml restart dashboard
```

### View Logs
```bash
docker-compose -f ops/docker-compose.yml logs -f dashboard  # Dashboard logs
docker-compose -f ops/docker-compose.yml logs -f ollama     # Ollama logs
```

### Rebuild (after code changes)
```bash
docker-compose -f ops/docker-compose.yml build --no-cache
docker-compose -f ops/docker-compose.yml up -d
```

## Persistent Data

All data is stored in local directories:
- `./data/` - Voice cache, databases
- `./tokens/` - OAuth tokens
- `./logs/` - Application logs
- `./config/` - Configuration files

These persist between container restarts.

## Configuration

Edit `config/config.yaml` before or after starting:

```yaml
# Voice Settings
voice:
  enabled: true
  model: "en_US-ryan-high"  # Pre-installed
  default_style: "droid"     # Options: droid, clean, radio, pa_system
  speed: 0.75                # 0.5x - 2x
  pitch: 0.85                # 0.5x - 2x

# Ollama (in Docker)
ollama:
  host: "ollama"      # Container name (don't change)
  port: 11434
  model: "tinyllama"  # Options: tinyllama, deepseek-coder-v2, etc.
```

After editing, restart dashboard:
```bash
docker-compose -f ops/docker-compose.yml restart dashboard
```

## Optional: Add More AI Models

```bash
# Pull a different model into Ollama
docker exec -it dashboard-ollama-1 ollama pull deepseek-coder-v2

# Update config.yaml to use new model
# Then restart dashboard
```

## Troubleshooting

### Dashboard not accessible
```bash
# Check if containers are running
docker-compose -f ops/docker-compose.yml ps

# Check dashboard logs
docker-compose -f ops/docker-compose.yml logs dashboard | tail -50
```

### Voice not working
```bash
# Check voice system in logs
docker-compose -f ops/docker-compose.yml logs dashboard | grep -i voice

# Voice is pre-installed, should work immediately
```

### Ollama not responding
```bash
# Check Ollama logs
docker-compose -f ops/docker-compose.yml logs ollama

# Verify Ollama API is responding
curl http://localhost:11434/api/tags

# Wait for model download (first start takes time)
```

### Port already in use
```bash
# Change port in docker-compose.yml
# Change "8008:8008" to "8009:8008" (or any free port)
# Then restart

# Or find what's using port 8008
lsof -i :8008
```

## Platform Support

| OS | Status | Notes |
|---|---|---|
| **Linux** | ✅ Full support | Native performance, uses Linux Piper binary |
| **macOS** | ✅ Full support | Docker Desktop required (Intel & Apple Silicon) |
| **Windows** | ✅ Full support | Docker Desktop with WSL2 recommended |

## Performance

- First run: ~2-3 minutes (Ollama model download)
- Subsequent runs: < 10 seconds
- Dashboard response: < 500ms
- Voice synthesis: 1-3 seconds

## Development Mode

Mount source code for live editing:

```bash
# Edit docker-compose.yml services.dashboard.volumes:
volumes:
  - ../src:/app/src:ro  # Read-only mount of src code
  - ../static:/app/static:ro
  - ./data:/app/data
  - ./tokens:/app/tokens
  - ./logs:/app/logs
  - ./config:/app/config

# Then restart
docker-compose -f ops/docker-compose.yml restart dashboard
```

## System Requirements

| Component | Minimum | Recommended |
|---|---|---|
| CPU | 2 cores | 4+ cores |
| RAM | 4GB | 8GB+ |
| Disk | 15GB | 20GB+ |
| Docker | 20.10+ | Latest |

## Cleanup

Remove all containers and data:
```bash
docker-compose -f ops/docker-compose.yml down -v
```

Remove only containers (keep data):
```bash
docker-compose -f ops/docker-compose.yml down
```

## Next Steps

1. **Configure OAuth** (Google, GitHub, etc.) - See [PROVIDER_SETUP.md](PROVIDER_SETUP.md)
2. **Add Weather API** - Get free key from openweathermap.org
3. **Connect Todoist/Calendar** - Optional integrations
4. **Customize Roger Voice** - Adjust speed/pitch in Voice Settings

Enjoy your Parker Dashboard! 🎉

