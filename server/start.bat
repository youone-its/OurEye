@echo off
echo ========================================
echo  OurEye Socket.IO Server - Quick Start
echo ========================================
echo.

REM Check if node_modules exists
if not exist "node_modules" (
    echo [1/3] Installing dependencies...
    call npm install
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to install dependencies
        pause
        exit /b 1
    )
) else (
    echo [1/3] Dependencies already installed
)

echo.
echo [2/3] Starting server...
echo.
echo Server akan running di http://localhost:3000
echo Health check: http://localhost:3000
echo Stats: http://localhost:3000/stats
echo.
echo Press Ctrl+C to stop server
echo.

REM Start server
call npm start

pause
