#!/bin/bash
# SIOP Training Hub - Startup Script (Unix/Mac)

# Detect if script is being run incorrectly with Python
# This check uses bash-specific syntax that will fail in Python
if [ -z "$BASH_VERSION" ]; then
    echo "❌ Error: This is a bash script, not a Python script!"
    echo ""
    echo "   You ran: python3 start.sh"
    echo "   But you should run: ./start.sh"
    echo "   Or: bash start.sh"
    echo ""
    echo "   This script will then run 'python3 server.py' internally."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Parse command line arguments for port
PORT=3000  # Default port
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -p, --port PORT    Port to run server on (default: 3000)"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                 # Start server on port 3000"
            echo "  $0 --port 3000     # Start server on port 3000"
            echo "  $0 -p 9000         # Start server on port 9000"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            echo "   Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate port is a number
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "❌ Error: Port must be a number between 1 and 65535"
    echo "   You specified: $PORT"
    exit 1
fi

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python 3 is not installed or not in PATH"
    echo "   Please install Python 3 and try again"
    exit 1
fi

# Check if port is already in use
if command -v lsof > /dev/null 2>&1; then
    if lsof -i :$PORT > /dev/null 2>&1; then
        echo "⚠️  Warning: Port $PORT is already in use!"
        echo "   Please stop the process using port $PORT, or use a different port:"
        echo "   Example: ./start.sh --port $((PORT + 1))"
        echo ""
        echo "   Processes using port $PORT:"
        lsof -i :$PORT
        exit 1
    fi
elif command -v netstat > /dev/null 2>&1; then
    if netstat -an 2>/dev/null | grep -q "\.$PORT.*LISTEN"; then
        echo "⚠️  Warning: Port $PORT appears to be in use!"
        echo "   Please stop the process using port $PORT, or use a different port:"
        echo "   Example: ./start.sh --port $((PORT + 1))"
        exit 1
    fi
fi

# Check if server is already running
if [ -f "server.pid" ]; then
    PID=$(cat server.pid)
    if ps -p $PID > /dev/null 2>&1; then
        echo "⚠️  Server is already running (PID: $PID)"
        echo "   To stop it, run: ./stop.sh"
        exit 1
    else
        # Remove stale PID file
        rm -f server.pid
    fi
fi

# Start the server in the background
echo "🚀 Starting SIOP Training Hub server on port $PORT..."
# Use -u flag for unbuffered output so logs appear immediately
python3 -u server.py --no-browser --port "$PORT" > server.log 2>&1 &
SERVER_PID=$!

# Save PID to file
echo $SERVER_PID > server.pid

# Wait a moment to check if server started successfully
sleep 3

# Check if process is still running
if ! ps -p $SERVER_PID > /dev/null 2>&1; then
    echo "❌ Server process exited immediately. Check server.log for details:"
    echo ""
    if [ -f "server.log" ]; then
        echo "--- Server Log Output ---"
        cat server.log
        echo "--- End of Log ---"
    else
        echo "   (No log file created)"
    fi
    rm -f server.pid
    exit 1
fi

# Show initial server output if available
if [ -f "server.log" ] && [ -s "server.log" ]; then
    echo ""
    echo "--- Server Startup Messages ---"
    cat server.log
    echo "--- End of Startup Messages ---"
    echo ""
fi

# Check if server is actually listening on the specified port
if command -v lsof > /dev/null 2>&1; then
    if ! lsof -i :$PORT > /dev/null 2>&1; then
        echo "⚠️  Warning: Server process is running but not listening on port $PORT"
        echo "   Check server.log for details:"
        if [ -f "server.log" ]; then
            tail -10 server.log
        fi
    fi
elif command -v netstat > /dev/null 2>&1; then
    if ! netstat -an | grep -q "\.$PORT.*LISTEN"; then
        echo "⚠️  Warning: Server process is running but port $PORT may not be listening"
        echo "   Check server.log for details:"
        if [ -f "server.log" ]; then
            tail -10 server.log
        fi
    fi
fi

# Check log file for common errors
if [ -f "server.log" ]; then
    if grep -qi "error\|exception\|traceback\|failed" server.log 2>/dev/null; then
        echo "⚠️  Warning: Errors detected in server.log. Server may not be running correctly."
        echo "   Recent log entries:"
        tail -10 server.log
        echo ""
    fi
fi

echo "✅ Server started successfully (PID: $SERVER_PID)"
echo "📋 Access the training hub at: http://localhost:$PORT/index.html"
echo "📋 Logs are being written to: server.log"
echo ""
echo "💡 To stop the server, run: ./stop.sh"
echo "💡 To view logs, run: tail -f server.log"
