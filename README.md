# Applications Folder Sync

Creates a single **Applications** folder in your user profile and fills it with flattened shortcuts from the Start Menu and Desktop (Mac-style). Run the BAT or the desktop shortcut to sync.

## What you need

- **Windows** (PowerShell)
- **Portable**: keep `SyncAppsFolder.bat` and `Setup-ApplicationsFolder.ps1` in the same folder. Move the folder anywhere; the BAT finds the script by relative path.

## How to use

1. Put this folder wherever you like (Desktop, USB, cloud folder, etc.).
2. Double-click **SyncAppsFolder.bat**.
3. It creates a desktop shortcut **"Sync Applications Folder"** and runs the sync.
4. Your apps appear in `%USERPROFILE%\Applications` (e.g. `C:\Users\You\Applications`).
5. Re-run the BAT or the shortcut anytime to update.

## Files

| File | Purpose |
|------|--------|
| `SyncAppsFolder.bat` | Run this (or the shortcut it creates). Uses `-ExecutionPolicy Bypass` so you don’t need to change system policy. |
| `Setup-ApplicationsFolder.ps1` | Main script: merges Start Menu, flattens shortcuts into Applications, skips uninstallers. |

## Notes

- Uninstallers and similar shortcuts are filtered out.
- Duplicate shortcut names are not overwritten (first one wins).
- The BAT and PS1 use no hardcoded paths; everything is relative to the BAT’s folder.
