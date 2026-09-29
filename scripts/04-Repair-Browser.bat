@echo off
setlocal
cd /d "%~dp0"
title Browser Hijack Repair (360 / hao.360.com)
echo ============================================================
echo   BROWSER HIJACK REPAIR
echo   Tip: close your browser windows before continuing.
echo ============================================================
echo.
echo STEP 1 - PREVIEW
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Repair-BrowserHijack.ps1"
echo.
set "GO="
set /p GO=Type GO and press Enter to APPLY the fixes, or press Enter to cancel:
if /i not "%GO%"=="GO" goto end
echo.
echo STEP 2 - EXECUTE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Repair-BrowserHijack.ps1" -Execute
echo.
echo Backups and a log were written to your Desktop folder:
echo   360-browser-backup
:end
echo.
pause
