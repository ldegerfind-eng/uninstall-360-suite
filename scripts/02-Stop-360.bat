@echo off
setlocal
cd /d "%~dp0"
title 360 Process / Service Stop
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Administrator rights are required.
  echo A UAC prompt will appear - click YES.
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
set "BK=%USERPROFILE%\Desktop\360-removal-backup"
if not exist "%BK%" mkdir "%BK%"
echo STEP 1 - PREVIEW
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-360Processes.ps1"
echo.
set "GO="
set /p GO=Type GO and press Enter to REALLY stop them, or press Enter to cancel:
if /i not "%GO%"=="GO" goto end
echo.
echo STEP 2 - EXECUTE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-360Processes.ps1" -Execute -LogFile "%BK%\stop-log.txt"
echo.
echo Done. If something refused to stop, just reboot - see SKILL.md Phase 5.
:end
echo.
pause
