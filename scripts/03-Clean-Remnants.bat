@echo off
setlocal
cd /d "%~dp0"
title 360 Remnant Cleanup
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Administrator rights are required.
  echo A UAC prompt will appear - click YES.
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
set "BK=%USERPROFILE%\Desktop\360-removal-backup"
if not exist "%BK%" mkdir "%BK%"
echo ============================================================
echo   STEP 1 - DRY RUN (nothing will be changed)
echo ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Remove-360Remnants.ps1"
echo.
echo ============================================================
echo   Review the list above before continuing.
echo   A System Restore point will be created if you proceed.
echo ============================================================
set "GO="
set /p GO=Type GO and press Enter to EXECUTE, or press Enter to cancel:
if /i not "%GO%"=="GO" goto end
echo.
echo STEP 2 - EXECUTE
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Remove-360Remnants.ps1" -Execute -CreateRestorePoint
echo.
echo ============================================================
echo   If some items FAILED: reboot the PC and run this again.
echo   Still failing? Use Safe Mode (SKILL.md Phase 5).
echo ============================================================
:end
echo.
pause
