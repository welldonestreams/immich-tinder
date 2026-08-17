@echo off
setlocal EnableExtensions
title Immich Tinder
echo ============================================
echo    Immich Tinder - local app
echo ============================================
echo.
where powershell >nul 2>nul
if errorlevel 1 goto :nops

if not exist "%~dp0server.ps1" goto :noextract
if not exist "%~dp0web\index.html" goto :noextract

echo    Starting the app... a browser window will open.
echo    This window closes itself. The separate server window
echo    that opens is the app - close that one to stop it.
echo.
start "Immich Tinder - local app" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"

timeout /t 2 /nobreak >nul
start "" http://127.0.0.1:2293/
exit /b 0

:nops
echo    PowerShell is required - Windows 10 or newer.
pause
exit /b 1

:noextract
echo.
echo    The app files are not next to this file.
echo    Extract the zip first, then run start.cmd from the extracted folder.
echo.
pause
exit /b 1
