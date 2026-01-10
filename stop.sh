#!/bin/bash
# SIOP Training Hub - Shutdown Script (Unix/Mac)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Default port (should match server.py)
PORT=8080

# Function to find processes using a port
find_port_processes() {
    local port=$1
    local pids=""
    
    # Try lsof first (most reliable)
    if command -v lsof > /dev/null 2>&1; then
        pids=$(lsof -ti :$port 2>/dev/null)
    # Fall back to netstat
    elif command -v netstat > /dev/null 2>&1; then
        pids=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 | sort -u)
    # Fall back to ss
    elif command -v ss > /dev/null 2>&1; then
        pids=$(ss -tlnp 2>/dev/null | grep ":$port " | grep -oP 'pid=\K[0-9]+' | sort -u)
    fi
    
    echo "$pids"
}

# Function to check if port is in use
is_port_in_use() {
    local port=$1
    if command -v lsof > /dev/null 2>&1; then
        lsof -i :$port > /dev/null 2>&1
    elif command -v netstat > /dev/null 2>&1; then
        netstat -an 2>/dev/null | grep -q "\.$port.*LISTEN"
    elif command -v ss > /dev/null 2>&1; then
        ss -tln 2>/dev/null | grep -q ":$port "
    else
        return 1
    fi
}

# Function to kill process and wait for port release
kill_process_and_wait() {
    local pid=$1
    local port=$2
    local max_wait=10
    
    echo "   Killing process $pid..."
    
    # Try graceful shutdown first (SIGTERM)
    kill $pid 2>/dev/null
    
    # Wait for process to stop and port to be released
    for i in $(seq 1 $max_wait); do
        if ! ps -p $pid > /dev/null 2>&1; then
            # Process is gone, wait a bit more for port to be released
            sleep 1
            if ! is_port_in_use $port; then
                echo "   ✅ Process stopped and port released."
                return 0
            fi
        fi
        sleep 1
    done
    
    # If still running, force kill
    if ps -p $pid > /dev/null 2>&1; then
        echo "   ⚠️  Process didn't stop gracefully. Force killing..."
        kill -9 $pid 2>/dev/null
        sleep 2
        
        if ! ps -p $pid > /dev/null 2>&1; then
            if ! is_port_in_use $port; then
                echo "   ✅ Process force stopped and port released."
                return 0
            else
                echo "   ⚠️  Process stopped but port still in TIME_WAIT (will clear in ~60 seconds)"
                return 0
            fi
        else
            echo "   ❌ Failed to kill process $pid"
            return 1
        fi
    fi
    
    # Check if port is still in use (might be TIME_WAIT)
    if is_port_in_use $port; then
        echo "   ⚠️  Port $port may be in TIME_WAIT state (will clear automatically)"
    fi
    
    return 0
}

echo "🛑 Stopping SIOP Training Hub server..."

# First, check if port is in use and find the process
PORT_PIDS=$(find_port_processes $PORT)
SERVER_PIDS=$(ps aux | grep "[p]ython3.*server.py" | awk '{print $2}')

# Collect all PIDs to kill
ALL_PIDS=""

# Add PID from file if it exists
if [ -f "server.pid" ]; then
    PID_FROM_FILE=$(cat server.pid 2>/dev/null)
    if [ -n "$PID_FROM_FILE" ] && ps -p $PID_FROM_FILE > /dev/null 2>&1; then
        ALL_PIDS="$ALL_PIDS $PID_FROM_FILE"
    else
        echo "⚠️  Stale PID file found. Removing it."
        rm -f server.pid
    fi
fi

# Add PIDs using the port
if [ -n "$PORT_PIDS" ]; then
    for pid in $PORT_PIDS; do
        if ps -p $pid > /dev/null 2>&1; then
            ALL_PIDS="$ALL_PIDS $pid"
        fi
    done
fi

# Add server.py processes
if [ -n "$SERVER_PIDS" ]; then
    for pid in $SERVER_PIDS; do
        if ps -p $pid > /dev/null 2>&1; then
            ALL_PIDS="$ALL_PIDS $pid"
        fi
    done
fi

# Remove duplicates
ALL_PIDS=$(echo $ALL_PIDS | tr ' ' '\n' | sort -u | tr '\n' ' ')

if [ -z "$ALL_PIDS" ]; then
    echo "✅ No server processes found running."
    
    # Check if port is still in TIME_WAIT
    if is_port_in_use $PORT; then
        echo "⚠️  Port $PORT appears to be in TIME_WAIT state."
        echo "   This is normal after stopping a server and will clear in ~60 seconds."
        echo "   You can either:"
        echo "   1. Wait ~60 seconds for the port to be released"
        echo "   2. Use a different port: ./start.sh --port 3001"
    else
        echo "✅ Port $PORT is available."
    fi
    
    rm -f server.pid
    exit 0
fi

# Kill all found processes
SUCCESS=true
for pid in $ALL_PIDS; do
    if ! kill_process_and_wait $pid $PORT; then
        SUCCESS=false
    fi
done

# Clean up PID file
rm -f server.pid

if $SUCCESS; then
    echo "✅ Server stopped successfully."
    
    # Final check for port
    sleep 1
    if is_port_in_use $PORT; then
        echo "⚠️  Note: Port $PORT may still be in TIME_WAIT state."
        echo "   If you get 'port in use' error, wait ~60 seconds or use: ./start.sh --port 3001"
    fi
else
    echo "❌ Some processes could not be stopped."
    exit 1
fi
