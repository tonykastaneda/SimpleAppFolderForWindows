@echo off
setlocal
REM No hard paths: script folder = same as this BAT (%~dp0). Change PS1_SCRIPT to use the other .ps1 if you prefer.
REM Why one .ps1 runs without ExecutionPolicy and the other doesn't: only the shortcut/BAT pass -ExecutionPolicy Bypass.
REM Double-clicking a .ps1 in Explorer uses default policy (often Restricted). Always run via this BAT or the desktop shortcut.
set "PS1_SCRIPT=Setup-ApplicationsFolder.ps1"
set "SCRIPT_PATH=%~dp0%PS1_SCRIPT%"

REM Create desktop shortcut that runs the PS1 with Bypass (no execution policy prompt)
PowerShell -ExecutionPolicy Bypass -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%USERPROFILE%\Desktop\Sync Applications Folder.lnk'); $s.TargetPath = 'PowerShell.exe'; $s.Arguments = '-ExecutionPolicy Bypass -File ^"%SCRIPT_PATH%^"'; $s.WorkingDirectory = '%~dp0'; $s.IconLocation = 'shell32.dll,21'; $s.Save()"
echo Shortcut created on your Desktop!

REM Run the sync script (same script, no hard path)
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
