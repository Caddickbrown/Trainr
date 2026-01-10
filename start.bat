@echo off
REM SIOP Training Hub - Startup Script (Windows)

cd /d "%~dp0"

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Error: Python is not installed or not in PATH
    echo    Please install Python 3 and try again
    pause
    exit /b 1
)

REM Check if server is already running
if exist "server.pid" (
    for /f "tokens=*" %%i in (server.pid) do set PID=%%i
    tasklist /FI "PID eq %PID%" 2>NUL | find /I /N "%PID%">NUL
    if "%ERRORLEVEL%"=="0" (
        echo ⚠️  Server is already running (PID: %PID%)
        echo    To stop it, run: stop.bat
        pause
        exit /b 1
    ) else (
        REM Remove stale PID file
        del server.pid
    )
)

echo 🚀 Starting SIOP Training Hub server...
start /B python server.py --no-browser > server.log 2>&1

REM Wait a moment
timeout /t 2 /nobreak >nul

REM Try to get the PID (Windows doesn't easily capture background process PID)
REM We'll use a simpler approach - just check if port is in use
netstat -ano | findstr ":8080" >nul
if errorlevel 1 (
    echo ❌ Server may have failed to start. Check server.log for details.
    pause
    exit /b 1
) else (
    echo ✅ Server started successfully
    echo 📋 Access the training hub at: http://localhost:8080/index.html
    echo 📋 Logs are being written to: server.log
    echo.
    echo 💡 To stop the server, run: stop.bat
    echo 💡 To view logs, open server.log in a text editor
    echo.
    echo Press any key to open the training hub in your browser...
    pause >nul
    start http://localhost:8080/index.html
)
