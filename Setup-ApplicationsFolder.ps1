# ============================================================
#  Setup-ApplicationsFolder.ps1
#  Creates a Mac-style "Applications" folder in your User root
#  Run periodically to keep it up to date.
#  Requires: Run as Administrator (needed for symlink creation)
# ============================================================

# ---- Paths ----
$userRoot          = [Environment]::GetFolderPath("UserProfile")
$userStartMenu     = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$allUsersStartMenu = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$desktop           = [Environment]::GetFolderPath("Desktop")
$applicationsPath  = "$userRoot\Applications"

# ---- Executable shortcut extensions we care about ----
$shortcutExts = @(".lnk", ".url", ".exe")

# ---- Patterns to exclude (case-insensitive substring match) ----
$uninstallerPatterns = @("uninstall", "uninst", "remove", "documentation", "help", "manual", "website", "readme", "support")

# ---- Helpers ----
function Is-AppShortcut($file) {
    return $shortcutExts -contains $file.Extension.ToLower()
}

function Is-Uninstaller($file) {
    $name = $file.BaseName.ToLower()
    foreach ($pattern in $uninstallerPatterns) {
        if ($name -match $pattern) { return $true }
    }
    return $false
}

# Conflict log
$skippedConflicts = [System.Collections.Generic.List[string]]::new()

# Copy a shortcut into the flat Applications folder
# Skips filtered items, logs conflicts but does not overwrite
function Copy-ToApplications($file) {
    if (Is-Uninstaller $file) {
        Write-Host "   [SKIPPED - Filtered] $($file.Name)" -ForegroundColor DarkGray
        return
    }

    $destination = Join-Path $applicationsPath $file.Name

    if (Test-Path $destination) {
        $skippedConflicts.Add($file.Name)
    } else {
        Copy-Item -Path $file.FullName -Destination $destination -Force
    }
}

Write-Host ""
Write-Host "=== Applications Folder Setup ===" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# STEP 0: Cleanup pass
# Removes any shortcuts already in Applications that match
# the filter list. Catches anything that got in before filters
# were added, or before new terms were added to the list.
# ------------------------------------------------------------
Write-Host "[0/4] Running cleanup pass on existing Applications folder..." -ForegroundColor Yellow

if (Test-Path $applicationsPath) {
    $existingShortcuts = Get-ChildItem -Path $applicationsPath -File -ErrorAction SilentlyContinue |
        Where-Object { Is-AppShortcut $_ }

    $cleanedCount = 0
    foreach ($file in $existingShortcuts) {
        if (Is-Uninstaller $file) {
            Remove-Item $file.FullName -Force
            Write-Host "   [REMOVED] $($file.Name)" -ForegroundColor DarkGray
            $cleanedCount++
        }
    }

    if ($cleanedCount -eq 0) {
        Write-Host "   Nothing to clean up." -ForegroundColor Green
    } else {
        Write-Host "   Removed $cleanedCount shortcut(s) matching filter list." -ForegroundColor Green
    }
} else {
    Write-Host "   Applications folder doesn't exist yet, skipping cleanup." -ForegroundColor DarkGray
}

# ------------------------------------------------------------
# STEP 1: Create the Applications folder (real folder, not symlink)
# We use a real folder since we are flattening everything into it
# ------------------------------------------------------------
Write-Host ""
Write-Host "[1/4] Checking Applications folder at: $applicationsPath" -ForegroundColor Yellow

if (-not (Test-Path $applicationsPath)) {
    New-Item -ItemType Directory -Path $applicationsPath -Force | Out-Null
    Write-Host "   Created Applications folder." -ForegroundColor Green
} else {
    $item = Get-Item $applicationsPath -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Host "   Found existing symlink at this path. Removing and replacing with real folder..." -ForegroundColor Yellow
        Remove-Item $applicationsPath -Force
        New-Item -ItemType Directory -Path $applicationsPath -Force | Out-Null
        Write-Host "   Replaced symlink with real folder." -ForegroundColor Green
    } else {
        Write-Host "   Applications folder already exists." -ForegroundColor Green
    }
}

# ------------------------------------------------------------
# STEP 2: Merge All Users Start Menu -> User Start Menu
# Copies shortcuts from system-wide folder that don't already
# exist in the user folder. Preserves subfolder structure there
# so Windows Search still works correctly.
# ------------------------------------------------------------
Write-Host ""
Write-Host "[2/4] Merging All Users Start Menu into User Start Menu..." -ForegroundColor Yellow

$allUsersShortcuts = Get-ChildItem -Path $allUsersStartMenu -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { Is-AppShortcut $_ }

$mergedCount = 0
foreach ($file in $allUsersShortcuts) {
    $relativePath = $file.FullName.Substring($allUsersStartMenu.Length).TrimStart("\")
    $destination  = Join-Path $userStartMenu $relativePath
    $destDir      = Split-Path $destination -Parent

    if (-not (Test-Path $destination)) {
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -Path $file.FullName -Destination $destination -Force
        $mergedCount++
    }
}
Write-Host "   Merged $mergedCount new shortcut(s) from All Users Start Menu." -ForegroundColor Green

# ------------------------------------------------------------
# STEP 3: Flatten all Start Menu shortcuts into Applications
# Pulls from both user and all-users start menus recursively,
# drops everything flat into the Applications root.
# Skips filtered items. Logs conflicts without overwriting.
# ------------------------------------------------------------
Write-Host ""
Write-Host "[3/4] Flattening Start Menu shortcuts into Applications..." -ForegroundColor Yellow

$startMenuSources = @($userStartMenu, $allUsersStartMenu)
$startMenuShortcuts = foreach ($source in $startMenuSources) {
    Get-ChildItem -Path $source -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { Is-AppShortcut $_ }
}

foreach ($file in $startMenuShortcuts) {
    Copy-ToApplications $file
}

Write-Host "   Done processing Start Menu shortcuts." -ForegroundColor Green

# ------------------------------------------------------------
# STEP 4: Flatten Desktop app shortcuts into Applications
# Skips filtered items. Logs conflicts without overwriting.
# ------------------------------------------------------------
Write-Host ""
Write-Host "[4/4] Scanning Desktop for app shortcuts..." -ForegroundColor Yellow

$desktopShortcuts = Get-ChildItem -Path $desktop -File -ErrorAction SilentlyContinue |
    Where-Object { Is-AppShortcut $_ }

foreach ($file in $desktopShortcuts) {
    Copy-ToApplications $file
}

Write-Host "   Done processing Desktop shortcuts." -ForegroundColor Green

# ------------------------------------------------------------
# Conflict Report
# ------------------------------------------------------------
if ($skippedConflicts.Count -gt 0) {
    Write-Host ""
    Write-Host "=== Conflict Report ($($skippedConflicts.Count) skipped) ===" -ForegroundColor Magenta
    Write-Host "The following shortcuts already existed in Applications and were NOT overwritten:" -ForegroundColor Magenta
    foreach ($name in $skippedConflicts) {
        Write-Host "   - $name" -ForegroundColor DarkYellow
    }
    Write-Host "To update these, delete them from '$applicationsPath' and re-run." -ForegroundColor DarkYellow
}

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
Write-Host ""
Write-Host "=== All done! ===" -ForegroundColor Cyan
Write-Host "Your Applications folder is at: $applicationsPath" -ForegroundColor White
Write-Host "Run this script anytime to sync new shortcuts." -ForegroundColor White
Write-Host ""
