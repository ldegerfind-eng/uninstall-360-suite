@echo off
setlocal
cd /d "%~dp0"
title 360 Remnant Scan (read-only)
echo ============================================================
echo   360 REMNANT SCAN - read-only, no admin required
echo ============================================================
echo.
set "OUT=%USERPROFILE%\Desktop\360-scan-report.txt"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Detect-360Remnants.ps1" -IncludeProfileScan -OutFile "%OUT%"
echo.
echo Report saved to: %OUT%
echo.
pause
