# Personal Dashboard - Docker Deployment Guide

## Quick Start

```bash
cd /home/glind/Projects/ramona/dashboard/ops

# 1. Create your environment file
cp .env.example .env
nano .env  # Edit with your credentials

# 2. Build and start
./deploy-dashboard.sh up

# 3. Access the dashboard
open http://parker.hoth.home:8020
```

## Features

- **Data Persistence**: SQLite database and all user data persists across restarts
- **Nightly Backups**: Auto-commits changes to git at 2 AM
- **Auto-Restart**: Container restarts after system reboot
- **Multi-User**: Support for multiple dashboard instances on different ports
- **Network Accessible**: Exposed to local network at configured hostname

## Configuration

### Environment Variables

Edit `ops/.env` to configure:

| Variable | Description | Default |
|----------|-------------|---------|
| `DASHBOARD_USER` | User identity for this instance | `parker` |
| `DASHBOARD_HOSTNAME` | Hostname for network access | `parker.hoth.home` |
| `DASHBOARD_PORT` | Port to expose | `8020` |
| `GIT_USER_NAME` | Git username for commits | - |
| `GIT_USER_EMAIL` | Git email for commits | - |
| `GIT_TOKEN` | GitHub token for push | - |
| `GIT_BRANCH` | Branch to commit to | `parker` |
| `ENABLE_NIGHTLY_BACKUP` | Enable auto-commits | `true` |
| `OLLAMA_HOST` | Ollama server URL | `http://ollama:11434` |

### DNS Setup (parker.hoth.home)

Add to your router's DNS or `/etc/hosts` on each client:

```
192.168.1.X    parker.hoth.home
```

Or use mDNS/Avahi for automatic discovery.

## Commands

```bash
# Start dashboard
./deploy-dashboard.sh up

# Stop dashboard
./deploy-dashboard.sh down

# Restart
./deploy-dashboard.sh restart

# View logs
./deploy-dashboard.sh logs
./deploy-dashboard.sh logs ollama

# Manual backup
./deploy-dashboard.sh backup

# Check status
./deploy-dashboard.sh status

# Open shell in container
./deploy-dashboard.sh shell

# Rebuild after code changes
./deploy-dashboard.sh build

# Pull latest and rebuild
./deploy-dashboard.sh pull
```

## Data Persistence

Data is stored in Docker named volumes:

| Volume | Contents |
|--------|----------|
| `dashboard_parker_data` | SQLite DB, skins, favorites, settings |
| `dashboard_parker_tokens` | OAuth tokens |
| `dashboard_parker_logs` | Application logs |
| `ollama_shared_data` | AI models |

To backup volumes manually:

```bash
# Backup
docker run --rm -v dashboard_parker_data:/data -v $(pwd):/backup alpine tar czf /backup/data-backup.tar.gz /data

# Restore
docker run --rm -v dashboard_parker_data:/data -v $(pwd):/backup alpine tar xzf /backup/data-backup.tar.gz -C /
```

## Auto-Start on Boot (Systemd)

```bash
# Install the service
sudo cp dashboard.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable dashboard.service

# Control the service
sudo systemctl start dashboard
sudo systemctl stop dashboard
sudo systemctl status dashboard
```

## Running Multiple Dashboards

To run dashboards for multiple users:

1. Create separate compose files or use profiles
2. Each user gets their own:
   - Port (8020, 8021, 8022, etc.)
   - Data volumes
   - Git branch
   - Hostname

Example for a second user:

```bash
# Create ramona's config
cp .env .env.ramona
# Edit with different user, port, branch
DASHBOARD_USER=ramona
DASHBOARD_PORT=8021
GIT_BRANCH=ramona

# Start with specific env
docker-compose -f docker-compose.multi.yml --env-file .env.ramona up -d
```

## Troubleshooting

### Dashboard won't start

```bash
# Check logs
./deploy-dashboard.sh logs

# Check container status
docker ps -a | grep dashboard

# Rebuild image
./deploy-dashboard.sh build
```

### Ollama not connecting

```bash
# Check if ollama is running
docker logs ollama-shared

# Pull a model
docker exec ollama-shared ollama pull llama3.2:1b
```

### Data not persisting

```bash
# Check volumes exist
docker volume ls | grep dashboard

# Inspect volume
docker volume inspect dashboard_parker_data
```

### Git backup failing

```bash
# Run backup manually and check output
./deploy-dashboard.sh backup

# Check git config in container
./deploy-dashboard.sh shell
git config --list
```

## Security Notes

- `.env` file contains secrets - don't commit it to git
- OAuth tokens are stored in a separate volume
- The container runs as root by default (can be changed)
- Consider using Docker secrets for production

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Local Network                        │
│                  parker.hoth.home                       │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼ :8020
┌─────────────────────────────────────────────────────────┐
│              Dashboard Container                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │  FastAPI + Uvicorn                              │   │
│  │  - Skin System (Roger/Demon)                    │   │
│  │  - Voice (Piper TTS)                            │   │
│  │  - Calendar, Email, Tasks                       │   │
│  │  - Music Player                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                         │                               │
│  ┌──────────┐  ┌───────┴────────┐  ┌──────────────┐   │
│  │  Cron    │  │  SQLite DB     │  │  Voice Cache │   │
│  │ (backup) │  │ (persistent)   │  │              │   │
│  └──────────┘  └────────────────┘  └──────────────┘   │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼ :11434
┌─────────────────────────────────────────────────────────┐
│              Ollama Container                           │
│  ┌─────────────────────────────────────────────────┐   │
│  │  llama3.2:1b / roger:latest                     │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```
