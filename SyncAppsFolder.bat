@echo off
setlocal
REM If not admin, re-launch this BAT with UAC so we can clean the system-wide Start Menu
net session >nul 2>&1
if %errorLevel% neq 0 (
  echo Requesting administrator rights...
  PowerShell -ExecutionPolicy Bypass -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

REM No hard paths: script folder = same as this BAT (%~dp0). Change PS1_SCRIPT to use the other .ps1 if you prefer.
set "PS1_SCRIPT=Setup-ApplicationsFolder.ps1"
set "SCRIPT_PATH=%~dp0%PS1_SCRIPT%"

REM Run the sync script (runs elevated so All Users Start Menu cleanup runs)
if exist "%SCRIPT_PATH%" (
  echo Running sync script...
  PowerShell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_PATH%"
) else (
  echo WARNING: Script not found: %SCRIPT_PATH%
  echo Move this BAT next to %PS1_SCRIPT% and run again.
)
echo.
pause
endlocal
