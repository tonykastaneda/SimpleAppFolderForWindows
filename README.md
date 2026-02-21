# Applications Folder Sync

Creates a `Applications` symlink in your user profile (`C:\Users\you\Applications`) that points live to your user Start Menu Programs folder — Mac-style. Run the BAT or desktop shortcut to sync.

## What you need

- **Windows** (PowerShell)
- **Run as Administrator** (required for symlink creation)
- Keep `SyncAppsFolder.bat` and `Setup-ApplicationsFolder.ps1` in the same folder

## How to use

1. Put this folder wherever you like (Desktop, USB, cloud folder, etc.)
2. Double-click **SyncAppsFolder.bat** — first run creates a desktop shortcut and runs the sync
3. Use the **"Sync Applications Folder"** desktop shortcut for all future runs
4. Your apps appear at `C:\Users\<you>\Applications`

## What it does (in order)

| Step | Action |
|------|--------|
| 1 | **Backup** — saves both Start Menu folders and Desktop shortcuts to a timestamped folder in your user root before touching anything |
| 2 | **Flatten + filter User Start Menu** — moves shortcuts out of subfolders into the root, deletes filtered items, removes empty folders |
| 3 | **Merge All Users Start Menu** — moves shortcuts from `C:\ProgramData\Microsoft\Windows\Start Menu\Programs` into your user Start Menu, filtered |
| 4 | **Move Desktop shortcuts** — moves app shortcuts from your Desktop into the user Start Menu, filtered |
| 5 | **Create symlink** — creates `C:\Users\<you>\Applications` pointing live to your user Start Menu Programs folder |

## Files

| File | Purpose |
|------|---------|
| `SyncAppsFolder.bat` | Run this. Uses `-ExecutionPolicy Bypass` so no system policy changes needed. |
| `Setup-ApplicationsFolder.ps1` | Main script — does all the work described above. |

## Notes

- Because `Applications` is a **live symlink**, any newly installed app will appear automatically without re-running the script
- Re-running the script is safe — it creates a fresh backup each time and only moves/deletes shortcuts, never your actual programs
- Filtered shortcut names: `uninstall`, `uninst`, `remove`, `documentation`, `help`, `manual`, `website`, `readme`, `support`
- If a shortcut with the same name already exists in the destination, the incoming one is discarded (first one wins)
- Backup folders are saved as `ApplicationsBackup_<timestamp>` in `C:\Users\<you>` — delete old ones manually whenever you like
