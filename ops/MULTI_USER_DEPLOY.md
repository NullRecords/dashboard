# Multi-Instance Family Dashboard Deployment

Deploy multiple dashboard instances on the same server, each with a unique URL.

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         Your Server             │
                    │                                 │
   parker.hoth.home │  ┌─────────┐   ┌─────────────┐ │
  ─────────────────►│  │ Traefik │───│ dashboard-  │ │  Port 8020
                    │  │  :80    │   │   parker    │ │
   sarah.hoth.home  │  │         │   └─────────────┘ │
  ─────────────────►│  │ Reverse │   ┌─────────────┐ │  Port 8021
                    │  │  Proxy  │───│ dashboard-  │ │
   greg.hoth.home   │  │         │   │   sarah     │ │
  ─────────────────►│  │         │   └─────────────┘ │
                    │  │         │   ┌─────────────┐ │  Port 8022
   ramona.hoth.home │  │         │───│ dashboard-  │ │
  ─────────────────►│  │         │   │    greg     │ │
                    │  │         │   └─────────────┘ │
                    │  │         │   ┌─────────────┐ │  Port 8023
                    │  │         │───│ dashboard-  │ │
                    │  └─────────┘   │   ramona    │ │
                    │                └─────────────┘ │
                    └─────────────────────────────────┘
```

## Quick Start

### 1. Configure Environment

```bash
cd ops
cp .env.family.example .env
nano .env  # Fill in your API keys
```

### 2. Setup Local DNS

Add these entries to your router, Pi-hole, or `/etc/hosts`:

```
192.168.1.XXX   parker.hoth.home
192.168.1.XXX   sarah.hoth.home
192.168.1.XXX   greg.hoth.home
192.168.1.XXX   ramona.hoth.home
```

Replace `192.168.1.XXX` with your server's IP address.

### 3. Deploy All Dashboards

```bash
cd ops
./deploy-family.sh
```

This will:
- Build Docker images for each user
- Start Traefik reverse proxy on port 80
- Start all 4 dashboard containers
- Each with isolated data volumes

### 4. Access Dashboards

- **Parker**: http://parker.hoth.home
- **Sarah**: http://sarah.hoth.home
- **Greg**: http://greg.hoth.home
- **Ramona**: http://ramona.hoth.home
- **Traefik Dashboard**: http://localhost:8080

## Management Commands

```bash
# Check status
./deploy-family.sh status

# View all logs
./deploy-family.sh logs

# View specific user's logs
./deploy-family.sh logs parker

# Restart all
./deploy-family.sh restart

# Stop all
./deploy-family.sh stop

# Rebuild specific user
./deploy-family.sh rebuild sarah

# DNS setup instructions
./deploy-family.sh dns
```

## Data Isolation

Each user has separate Docker volumes:
- `dashboard_<user>_data` - SQLite database, settings
- `dashboard_<user>_tokens` - OAuth tokens
- `dashboard_<user>_logs` - Application logs

## Git Branches

Each dashboard commits to its own branch nightly at 2 AM:
- Parker → `parker` branch
- Sarah → `sarah` branch
- Greg → `greg` branch
- Ramona → `ramona` branch

## Adding a New User

1. Add a new service block in `docker-compose.family.yml`:

```yaml
  dashboard-newuser:
    build:
      context: ..
      dockerfile: ops/Dockerfile.multi
      args:
        DASHBOARD_USER: newuser
        DASHBOARD_PORT: 8024
    container_name: dashboard-newuser
    hostname: newuser.hoth.home
    environment:
      - DASHBOARD_USER=newuser
      - DASHBOARD_PORT=8024
      - GIT_BRANCH=newuser
      # ... copy other env vars from existing service
    volumes:
      - newuser_data:/app/data
      - newuser_tokens:/app/tokens
      - newuser_logs:/app/logs
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.newuser.rule=Host(`newuser.hoth.home`)"
      - "traefik.http.services.newuser.loadbalancer.server.port=8024"
    # ... rest of config
```

2. Add volumes:

```yaml
volumes:
  newuser_data:
    name: dashboard_newuser_data
  # ... etc
```

3. Add DNS entry for `newuser.hoth.home`

4. Redeploy: `./deploy-family.sh`

## Troubleshooting

### Can't access by hostname
- Check DNS entries are correct
- Try `ping parker.hoth.home` to verify resolution
- Ensure Traefik is running: `docker ps | grep traefik`

### Container won't start
```bash
# Check logs
docker logs dashboard-parker

# Check Traefik routing
curl -H "Host: parker.hoth.home" http://localhost/
```

### Ollama not connecting
Ensure `OLLAMA_HOST=http://host.docker.internal:11434` in `.env`
and Ollama is running on the host.

## Resource Usage

Each dashboard container uses approximately:
- **Memory**: 200-400 MB
- **CPU**: Minimal (< 1% idle)
- **Storage**: 500 MB image + user data

Total for 4 users: ~1.5 GB RAM, ~2 GB storage
