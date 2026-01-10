@echo off
REM SIOP Training Hub - Shutdown Script (Windows)

cd /d "%~dp0"

set PORT=8080
if not "%~1"=="" (
    set PORT=%~1
)

echo 🛑 Stopping SIOP Training Hub server...

REM Find and kill Python processes running server.py
for /f "tokens=2" %%i in ('tasklist /FI "IMAGENAME eq python.exe" /FO LIST ^| findstr /I "PID"') do (
    set PID=%%i
    wmic process where "ProcessId=%%i" get CommandLine 2>nul | findstr /I "server.py" >nul
    if not errorlevel 1 (
        echo Stopping process %%i...
        taskkill /PID %%i /F >nul 2>&1
    )
)

REM Also try to kill by port (if netstat is available)
for /f "tokens=5" %%i in ('netstat -ano ^| findstr ":%PORT%" ^| findstr "LISTENING"') do (
    echo Stopping process on port %PORT% (PID: %%i)...
    taskkill /PID %%i /F >nul 2>&1
)

REM Remove PID file if it exists
if exist "server.pid" del server.pid

echo ✅ Server stopped.
timeout /t 2 /nobreak >nul
