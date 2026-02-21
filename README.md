# Applications Folder (Symlink + Move + Flatten)

One **Applications** folder in your user profile that shows all your app shortcuts in a single flat list. It’s a symlink to your user Start Menu; the script moves shortcuts there from the system Start Menu and Desktop, flattens subfolders, and removes junk (uninstallers, help, readme, etc.).

---

## The plan (what the script does)

1. **Symlink**  
   `C:\Users\<You>\Applications` → points to  
   `C:\Users\<You>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs`  
   So “Applications” is just another view of your user Start Menu folder.

2. **Move (not copy)**  
   All shortcuts from the **All Users** (system-wide) Start Menu are **moved** into your **user** Start Menu folder. Desktop app shortcuts are **moved** into that same folder. Nothing is left as duplicates in the original locations (except what we filter out).

3. **Flatten**  
   Shortcuts that landed in subfolders are **moved to the root** of the user Start Menu (so Applications shows one flat list). Empty folders are removed.

4. **Filter and delete**  
   Shortcuts whose names match the filter list are **deleted** from both the user Start Menu and the All Users Start Menu. Empty folders are removed again after filtering.

---

## Folders involved

| Folder | Path | Role |
|--------|------|------|
| **Applications** (symlink) | `C:\Users\<You>\Applications` | What you open; points to user Start Menu. |
| **User Start Menu** | `C:\Users\<You>\AppData\Roaming\...\Start Menu\Programs` | Real folder; everything is moved here and flattened. |
| **All Users Start Menu** | `C:\ProgramData\Microsoft\Windows\Start Menu\Programs` | System-wide; shortcuts are **moved** out of here, then filtered and empty folders are cleaned. |
| **Desktop** | Your desktop folder | App shortcuts are **moved** from here into the user Start Menu. |

---

## How to use

1. Keep **SyncAppsFolder.bat** and **Setup-ApplicationsFolder.ps1** in the **same folder** (no hard paths; you can move the folder anywhere).
2. **Double‑click** `SyncAppsFolder.bat`.
3. Approve the **UAC** prompt when it asks for administrator rights.
4. The script runs in a new elevated window: symlink → move → flatten → filter → clean empty folders.

You can run the BAT again anytime to re-sync (e.g. after new installs).

---

## What runs what

- **SyncAppsFolder.bat**  
  - If not running as admin, it **re-launches itself** with “Run as administrator” so you get **one UAC prompt** and don’t have to right‑click “Run as administrator.”  
  - Then it runs **Setup-ApplicationsFolder.ps1** with `-ExecutionPolicy Bypass` so PowerShell doesn’t block the script.  
  - It does **not** create a desktop shortcut; it only runs the script in the same folder.

- **Setup-ApplicationsFolder.ps1**  
  - Step 1: Create/repair symlink `Applications` → user Start Menu.  
  - Step 2: **Move** all shortcuts from All Users Start Menu → user Start Menu.  
  - Step 3: **Move** Desktop shortcuts → user Start Menu root.  
  - Step 4: **Flatten** user Start Menu (all shortcuts to root), then remove empty folders.  
  - Step 5: **Filter** user Start Menu (delete matching shortcuts), then remove empty folders.  
  - Step 6: **Clean** All Users Start Menu (delete filtered shortcuts, remove empty folders).

---

## Filter list (shortcuts with these in the name are deleted)

Case-insensitive substring match:  
**uninstall**, **uninst**, **remove**, **documentation**, **help**, **manual**, **website**, **readme**, **support**

---

## Fixes and behavior that were added

- **BAT no longer creates a desktop shortcut**  
  It only runs the script in the folder; no shortcut is created on the desktop.

- **UAC self-elevation**  
  The BAT checks for admin; if not admin, it launches itself with “Run as administrator” so you only need to double‑click and approve UAC once.

- **No hard paths**  
  The BAT uses `%~dp0` so the script path is always “same folder as the BAT.” You can move the folder anywhere; only the script **name** is set at the top of the BAT (`Setup-ApplicationsFolder.ps1`).

- **BAT PowerShell line-continuation fix**  
  The BAT used to pass `^` into PowerShell and break. The shortcut-creation command was put on one line and inner quotes fixed so the BAT runs correctly without “The term '^' is not recognized.”

- **Symlink-based design**  
  Applications is a **symlink** to the user Start Menu (not a separate real folder with copies). All shortcuts live in the user Start Menu; “Applications” is just another path to that folder. Everything is **moved** (not copied) from All Users and Desktop, then flattened and filtered.

- **Empty folder removal**  
  - A folder is treated as **empty** if it has **no subfolders** and **no shortcut files** (`.lnk`, `.url`, `.exe`). Folders that only contain things like `desktop.ini` are removed.  
  - Removal uses **multiple passes** (deepest folders first) and **`-LiteralPath`** so paths with special characters don’t break.  
  - Empty folders are removed after flattening (Step 4) and after filtering (Steps 5 and 6).

---

## Files in this repo

| File | Purpose |
|------|--------|
| **SyncAppsFolder.bat** | Double‑click to run; asks for admin via UAC, then runs the PowerShell script. |
| **Setup-ApplicationsFolder.ps1** | Does the symlink, move, flatten, filter, and empty-folder cleanup. |
| **README.md** | This file. |

---

## Requirements

- **Windows** (PowerShell).
- **Administrator** rights when running the BAT (so the symlink and All Users Start Menu changes can be made). The BAT handles asking for elevation via UAC.
