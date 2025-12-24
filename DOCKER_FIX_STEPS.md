# Docker Fix Steps

## The Problem
The anxiety feed error persists because:
1. Old JavaScript is cached in browser
2. Docker container may have stale files

## Quick Fix (Try This First)

### On Local Machine:
```bash
cd /home/glind/Projects/ramona/dashboard

# 1. Hard refresh browser (Ctrl+Shift+R or Cmd+Shift+R)
#    This clears JavaScript cache

# 2. Restart server to reload template
pkill -f "uvicorn.*8020"
sleep 2
source .venv/bin/activate
uvicorn src.main:app --host 0.0.0.0 --port 8020 --reload
```

## If Quick Fix Doesn't Work

### Full Docker Rebuild:
```bash
cd /home/glind/Projects/ramona/dashboard/ops

# Stop and remove containers
docker-compose down

# Rebuild from scratch (no cache)
docker-compose build --no-cache

# Start fresh
docker-compose up -d

# Check logs
docker-compose logs -f dashboard
```

## What Was Fixed

1. **Assistant Link** - Now uses `skin.assistant.url` for correct routing
   - Alice → `/obi-wan`
   - Roger → `/assistant`
   - Dracula → `/demon` (or whatever is configured)

2. **Anxiety Feed Error** - Completely removed the function
   - No more `Cannot set properties of null` error
   - Function was trying to access non-existent HTML element

## Testing

After restart, check browser console (F12):
- Should NOT see "Anxiety feed error"
- Should see "🚀 ALL RELEVANT DATA LOADERS CALLED"
- Clicking assistant link should go to correct page

## If Still Having Issues

The Docker setup might be too complex. Consider:
1. Using local Python directly (faster iteration)
2. Simplifying docker-compose.yml
3. Using volume mounts for live code updates

Current startup.sh is reliable for local development.
