# ============================================================
#  Setup-ApplicationsFolder.ps1
#  Applications = symlink to User Start Menu. Everything moved
#  there and flattened. Filter removes uninstallers etc.
#  Run as Administrator (needed for symlink + All Users moves).
# ============================================================

# ---- Paths ----
$userRoot          = [Environment]::GetFolderPath("UserProfile")
$userStartMenu     = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
$allUsersStartMenu = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$desktop           = [Environment]::GetFolderPath("Desktop")
$publicDesktop     = [Environment]::GetFolderPath("CommonDesktopDirectory")   # C:\Users\Public\Desktop
$applicationsPath  = "$userRoot\Applications"

# Resolve actual Desktop path (handles OneDrive/redirects); fallback to standard if registry read fails
function Get-ActualDesktopPath {
    try {
        $key = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
        $desktopReg = (Get-ItemProperty -Path $key -ErrorAction Stop).Desktop
        if ($desktopReg) {
            $resolved = [Environment]::ExpandEnvironmentVariables($desktopReg)
            if ([System.IO.Directory]::Exists($resolved)) { return $resolved }
        }
    } catch { }
    return [Environment]::GetFolderPath("Desktop")
}

# ---- Executable shortcut extensions we care about ----
$shortcutExts = @(".lnk", ".url", ".exe")

# ---- Patterns to exclude: filter and DELETE (case-insensitive substring match) ----
$filterPatterns = @("uninstall", "uninst", "remove", "documentation", "help", "manual", "website", "readme", "support")

# ---- Helpers ----
function Is-AppShortcut($file) {
    return $shortcutExts -contains $file.Extension.ToLower()
}

function Is-Filtered($file) {
    $name = $file.BaseName.ToLower()
    foreach ($pattern in $filterPatterns) {
        if ($name -match $pattern) { return $true }
    }
    return $false
}

function Remove-EmptyFolders($path) {
    $removed = 0
    $maxPasses = 50
    $pass = 0
    while ($pass -lt $maxPasses) {
        $pass++
        $allDirs = @(Get-ChildItem -Path $path -Recurse -Directory -ErrorAction SilentlyContinue | Sort-Object { $_.FullName.Length } -Descending)
        $emptyDirs = @()
        foreach ($dir in $allDirs) {
            $children = @(Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue)
            $subdirs = @($children | Where-Object { $_.PSIsContainer })
            $shortcuts = @($children | Where-Object { -not $_.PSIsContainer -and (Is-AppShortcut $_) })
            $effectivelyEmpty = ($subdirs.Count -eq 0) -and ($shortcuts.Count -eq 0)
            if ($effectivelyEmpty) {
                $emptyDirs += $dir
            }
        }
        if ($emptyDirs.Count -eq 0) { break }
        foreach ($dir in $emptyDirs) {
            if (-not (Test-Path -LiteralPath $dir.FullName)) { continue }
            Remove-Item -LiteralPath $dir.FullName -Force -Recurse -ErrorAction SilentlyContinue
            if (-not (Test-Path -LiteralPath $dir.FullName)) { $removed++ }
        }
    }
    return $removed
}

Write-Host ""
Write-Host "=== Applications Folder Setup (symlink + move + flatten) ===" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# STEP 1: Symlink Applications -> User Start Menu
# ------------------------------------------------------------
Write-Host "[1/7] Setting up symlink: Applications -> User Start Menu..." -ForegroundColor Yellow

if (Test-Path $applicationsPath) {
    $item = Get-Item $applicationsPath -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $target = (Get-Item $applicationsPath).Target
        if ($target -eq $userStartMenu) {
            Write-Host "   Symlink already correct." -ForegroundColor Green
        } else {
            Remove-Item $applicationsPath -Force
            New-Item -ItemType SymbolicLink -Path $applicationsPath -Target $userStartMenu -Force | Out-Null
            Write-Host "   Recreated symlink (was pointing elsewhere)." -ForegroundColor Green
        }
    } else {
        Remove-Item $applicationsPath -Force -Recurse
        New-Item -ItemType SymbolicLink -Path $applicationsPath -Target $userStartMenu -Force | Out-Null
        Write-Host "   Replaced folder with symlink." -ForegroundColor Green
    }
} else {
    New-Item -ItemType SymbolicLink -Path $applicationsPath -Target $userStartMenu -Force | Out-Null
    Write-Host "   Symlink created." -ForegroundColor Green
}

# ------------------------------------------------------------
# STEP 2: Move all shortcuts from All Users Start Menu -> User Start Menu
# (Preserve relative path; we flatten later.)
# ------------------------------------------------------------
Write-Host ""
Write-Host "[2/7] Moving shortcuts from All Users Start Menu to User Start Menu..." -ForegroundColor Yellow

$allUsersShortcuts = Get-ChildItem -Path $allUsersStartMenu -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { Is-AppShortcut $_ }

$movedCount = 0
foreach ($file in $allUsersShortcuts) {
    $relativePath = $file.FullName.Substring($allUsersStartMenu.Length).TrimStart("\")
    $destination  = Join-Path $userStartMenu $relativePath
    $destDir      = Split-Path $destination -Parent

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Move-Item -Path $file.FullName -Destination $destination -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $file.FullName)) { $movedCount++ }
}
Write-Host "   Moved $movedCount shortcut(s)." -ForegroundColor Green

# ------------------------------------------------------------
# STEP 3: Move Desktop shortcuts (User + Public) into User Start Menu root
# Conflict resolution: overwrite (last one wins). No "(2)" copies.
# ------------------------------------------------------------
Write-Host ""
Write-Host "[3/7] Moving Desktop shortcuts into User Start Menu (Applications)..." -ForegroundColor Yellow

$desktopMoved = 0
$desktopSources = @(
    (Get-ActualDesktopPath),
    $publicDesktop
)

foreach ($desktopFolder in $desktopSources) {
    if (-not (Test-Path -LiteralPath $desktopFolder)) { continue }
    $shortcuts = Get-ChildItem -LiteralPath $desktopFolder -File -ErrorAction SilentlyContinue |
        Where-Object { Is-AppShortcut $_ }
    foreach ($file in $shortcuts) {
        $destination = Join-Path $userStartMenu $file.Name
        Move-Item -LiteralPath $file.FullName -Destination $destination -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $file.FullName)) { $desktopMoved++ }
    }
}

Write-Host "   Moved $desktopMoved desktop shortcut(s) (user + Public)." -ForegroundColor Green

# ------------------------------------------------------------
# STEP 4: Clean Desktop — remove ALL shortcut files (leave folders only)
# Cleans both USER desktop and PUBLIC desktop (C:\Users\Public\Desktop).
# ------------------------------------------------------------
Write-Host ""
Write-Host "[4/7] Cleaning Desktop: removing shortcut files (folders left alone)..." -ForegroundColor Yellow

$shortcutExtList = @(".lnk", ".url", ".exe")
function Remove-ShortcutFilesFromFolder($folderPath) {
    if (-not (Test-Path -LiteralPath $folderPath)) { return 0 }
    $removed = 0
    $filesToDelete = @(Get-ChildItem -LiteralPath $folderPath -File -ErrorAction SilentlyContinue |
        Where-Object { $shortcutExtList -contains $_.Extension.ToLowerInvariant() })
    foreach ($file in $filesToDelete) {
        $path = $file.FullName
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            if ($file.IsReadOnly) { $file.Attributes = $file.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly) }
            Remove-Item -LiteralPath $path -Force -ErrorAction Stop
        } catch {
            try { [System.IO.File]::Delete($path) } catch { }
        }
        if (-not (Test-Path -LiteralPath $path)) { $removed++ }
    }
    return $removed
}

$userDesktopPath = Get-ActualDesktopPath
Write-Host "   User Desktop: $userDesktopPath" -ForegroundColor DarkGray
$desktopRemoved = Remove-ShortcutFilesFromFolder $userDesktopPath

Write-Host "   Public Desktop: $publicDesktop" -ForegroundColor DarkGray
$publicRemoved = Remove-ShortcutFilesFromFolder $publicDesktop

Write-Host "   Removed $desktopRemoved from user Desktop, $publicRemoved from Public Desktop." -ForegroundColor Green

# ------------------------------------------------------------
# STEP 5: Flatten — pull all shortcuts from subfolders to root of User Start Menu
# ------------------------------------------------------------
Write-Host ""
Write-Host "[5/7] Flattening: moving all shortcuts to root..." -ForegroundColor Yellow

$subfolderShortcuts = Get-ChildItem -Path $userStartMenu -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { Is-AppShortcut $_ } |
    Where-Object { $_.DirectoryName -ne $userStartMenu }

$flattened = 0
foreach ($file in $subfolderShortcuts) {
    $dest = Join-Path $userStartMenu $file.Name
    if ($file.FullName -eq $dest) { continue }
    Move-Item -Path $file.FullName -Destination $dest -Force -ErrorAction SilentlyContinue
    $flattened++
}
Write-Host "   Moved $flattened shortcut(s) to root." -ForegroundColor Green

$emptyRemoved = Remove-EmptyFolders $userStartMenu
if ($emptyRemoved -gt 0) {
    Write-Host "   Removed $emptyRemoved empty folder(s)." -ForegroundColor Green
}

# ------------------------------------------------------------
# STEP 5: Filter and delete (uninstall, help, readme, etc.) from User Start Menu
# ------------------------------------------------------------
Write-Host ""
Write-Host "[6/7] Filtering: removing uninstallers and junk from User Start Menu (Applications)..." -ForegroundColor Yellow

$userShortcuts = Get-ChildItem -Path $userStartMenu -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { Is-AppShortcut $_ }

$filteredOut = 0
foreach ($file in $userShortcuts) {
    if (Is-Filtered $file) {
        Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "   [REMOVED] $($file.Name)" -ForegroundColor DarkGray
        $filteredOut++
    }
}
Write-Host "   Removed $filteredOut filtered shortcut(s)." -ForegroundColor Green
$emptyRemoved2 = Remove-EmptyFolders $userStartMenu
if ($emptyRemoved2 -gt 0) {
    Write-Host "   Removed $emptyRemoved2 empty folder(s)." -ForegroundColor Green
}

# ------------------------------------------------------------
# STEP 6: Clean All Users Start Menu — filter and delete, remove empty folders
# ------------------------------------------------------------
Write-Host ""
Write-Host "[7/7] Cleaning All Users Start Menu..." -ForegroundColor Yellow

$allUsersRemaining = Get-ChildItem -Path $allUsersStartMenu -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { Is-AppShortcut $_ }

$allUsersFiltered = 0
foreach ($file in $allUsersRemaining) {
    if (Is-Filtered $file) {
        Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        $allUsersFiltered++
    }
}
Write-Host "   Removed $allUsersFiltered filtered shortcut(s) from All Users." -ForegroundColor Green
$allUsersEmpty = Remove-EmptyFolders $allUsersStartMenu
if ($allUsersEmpty -gt 0) {
    Write-Host "   Removed $allUsersEmpty empty folder(s) from All Users." -ForegroundColor Green
}

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
Write-Host ""
Write-Host "=== All done! ===" -ForegroundColor Cyan
Write-Host "Applications (symlink) is at: $applicationsPath" -ForegroundColor White
Write-Host "It points to: $userStartMenu" -ForegroundColor White
Write-Host ""
