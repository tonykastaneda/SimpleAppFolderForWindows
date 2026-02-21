@echo off
setlocal
REM No hard paths: script folder = same as this BAT (%~dp0). Change PS1_SCRIPT to use the other .ps1 if you prefer.
set "PS1_SCRIPT=Setup-ApplicationsFolder.ps1"
set "SCRIPT_PATH=%~dp0%PS1_SCRIPT%"

REM Run the sync script
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
