#!/bin/bash
# Dashboard Management Script

case "$1" in
    start)
        echo "🚀 Starting all dashboards..."
        cd /home/glind/dashboards/master && source .venv/bin/activate && uvicorn src.main:app --host 0.0.0.0 --port 8020 > dashboard.log 2>&1 & echo $! > dashboard.pid
        cd /home/glind/dashboards/parker && source .venv/bin/activate && uvicorn src.main:app --host 0.0.0.0 --port 8021 > dashboard.log 2>&1 & echo $! > dashboard.pid
        cd /home/glind/dashboards/ramona && source .venv/bin/activate && uvicorn src.main:app --host 0.0.0.0 --port 8022 > dashboard.log 2>&1 & echo $! > dashboard.pid
        cd /home/glind/dashboards/sarah && source .venv/bin/activate && uvicorn src.main:app --host 0.0.0.0 --port 8023 > dashboard.log 2>&1 & echo $! > dashboard.pid
        cd /home/glind/dashboards/greg && source .venv/bin/activate && uvicorn src.main:app --host 0.0.0.0 --port 8024 > dashboard.log 2>&1 & echo $! > dashboard.pid
        sleep 3
        echo "✅ All dashboards started!"
        ;;
    stop)
        echo "🛑 Stopping all dashboards..."
        pkill -f "uvicorn.*src.main:app" 2>/dev/null || true
        rm -f /home/glind/dashboards/*/dashboard.pid
        echo "✅ All dashboards stopped!"
        ;;
    status)
        echo "📊 Dashboard Status"
        echo "==================="
        ps aux | grep "uvicorn.*src.main:app" | grep -v grep | awk '{print "✅ PID " $2 " on port " substr($0, index($0, "--port") + 7, 4)}'
        echo ""
        echo "Port checks:"
        for port in 8020 8021 8022 8023 8024; do
            if curl -s -o /dev/null -w "" http://localhost:$port; then
                echo "✅ Port $port: ONLINE"
            else
                echo "❌ Port $port: OFFLINE"
            fi
        done
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        echo ""
        echo "Dashboard URLs:"
        echo "  Master (Roger): http://hoth.home:8020"
        echo "  Parker:         http://hoth.home:8021"
        echo "  Ramona:         http://hoth.home:8022"
        echo "  Sarah:          http://hoth.home:8023"
        echo "  Greg:           http://hoth.home:8024"
        exit 1
        ;;
esac
