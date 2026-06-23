#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures Windows 11 File Explorer settings.
.DESCRIPTION
    - Shows file extensions for known types
    - Shows hidden files and folders
    - Shows OS/system protected files
    - Displays full path in title bar and address bar
    - Opens Explorer to "This PC" instead of Quick Access
    - Disables Recent Files in Quick Access
    - Disables Frequent Folders in Quick Access
    - Disables sync provider notifications
    - Expands tree to current folder
    - Shows status bar
    Safe to run multiple times.
#>

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
$LogDir  = Join-Path $PSScriptRoot 'logs'
$LogFile = Join-Path $LogDir 'explorer_settings.log'
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

function Set-Reg {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = 'DWord'
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
        Write-Log "  Created key : $Path"
    }
    try {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        Write-Log "  SET  $Name = $Value"
    } catch {
        Write-Log "  WARN $Name : $_" 'WARN'
    }
}

# ----------------------------------------------------------------
# Paths
# ----------------------------------------------------------------
$Advanced      = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$ExplorerRoot  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
$CabinetState  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState'

Write-Log ('=' * 60)
Write-Log 'Configuring File Explorer'
Write-Log ('=' * 60)

# ── File extensions ───────────────────────────────────────────────
Write-Log '--- File Extensions ---'
Set-Reg -Path $Advanced -Name 'HideFileExt' -Value 0
# 0 = show extensions (default Win is 1 = hide)

# ── Hidden files ─────────────────────────────────────────────────
Write-Log '--- Hidden Files ---'
Set-Reg -Path $Advanced -Name 'Hidden'          -Value 1  # 1=show hidden, 2=hide
Set-Reg -Path $Advanced -Name 'ShowSuperHidden' -Value 1  # show system/OS files

# ── Full path in title bar ────────────────────────────────────────
Write-Log '--- Full Path Display ---'
Set-Reg -Path $CabinetState -Name 'FullPath'        -Value 1
Set-Reg -Path $CabinetState -Name 'FullPathAddress' -Value 1

# ── Open to This PC ──────────────────────────────────────────────
Write-Log '--- Default Open Location ---'
# 1 = This PC   |   2 = Quick Access
Set-Reg -Path $Advanced -Name 'LaunchTo' -Value 1

# ── Quick Access — recent files ───────────────────────────────────
Write-Log '--- Quick Access: Recent Files ---'
Set-Reg -Path $ExplorerRoot -Name 'ShowRecent'        -Value 0
Set-Reg -Path $Advanced     -Name 'Start_TrackDocs'   -Value 0

# ── Quick Access — frequent folders ──────────────────────────────
Write-Log '--- Quick Access: Frequent Folders ---'
Set-Reg -Path $ExplorerRoot -Name 'ShowFrequent'      -Value 0

# ── Sync provider notifications (OneDrive / SharePoint ads) ──────
Write-Log '--- Sync Provider Notifications ---'
Set-Reg -Path $Advanced -Name 'ShowSyncProviderNotifications' -Value 0

# ── Navigation pane: expand to open folder ───────────────────────
Write-Log '--- Navigation Pane ---'
Set-Reg -Path $Advanced -Name 'NavPaneExpandToCurrentFolder' -Value 1
Set-Reg -Path $Advanced -Name 'NavPaneShowAllFolders'        -Value 0

# ── Status bar ───────────────────────────────────────────────────
Write-Log '--- Status Bar ---'
Set-Reg -Path $Advanced -Name 'ShowStatusBar' -Value 1

# ── Compact view (Windows 11 added extra padding — keep it off) ──
Write-Log '--- View Density ---'
Set-Reg -Path $Advanced -Name 'UseCompactMode' -Value 0

# ── Merge conflict highlighting ───────────────────────────────────
Write-Log '--- Folder Merge Conflict Highlight ---'
Set-Reg -Path $Advanced -Name 'HideMergeConflicts' -Value 0

# ── App launch tracking (used for Start suggestions) ─────────────
Write-Log '--- App Launch Tracking ---'
Set-Reg -Path $Advanced -Name 'Start_TrackProgs' -Value 0

# ----------------------------------------------------------------
# Clear Recent / Frequent jump-list caches (privacy)
# ----------------------------------------------------------------
Write-Log '--- Clearing Recent Items cache ---'
try {
    $recentPath = [System.Environment]::GetFolderPath('Recent')
    Remove-Item "$recentPath\*" -Force -Recurse -ErrorAction SilentlyContinue
    Write-Log "  Cleared: $recentPath"

    $automaticDest = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
    Remove-Item "$automaticDest\*" -Force -Recurse -ErrorAction SilentlyContinue
    Write-Log "  Cleared AutomaticDestinations"

    $customDest = "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
    Remove-Item "$customDest\*" -Force -Recurse -ErrorAction SilentlyContinue
    Write-Log "  Cleared CustomDestinations"
} catch {
    Write-Log "  Could not fully clear recent items: $_" 'WARN'
}

# ----------------------------------------------------------------
# Restart Explorer
# ----------------------------------------------------------------
Write-Log '--- Restarting File Explorer ---'
try {
    Stop-Process -Name 'explorer' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process 'explorer.exe'
    Write-Log '  Explorer restarted.'
} catch {
    Write-Log "  Could not restart Explorer: $_ — sign out to apply changes." 'WARN'
}

Write-Log ('=' * 60)
Write-Log 'File Explorer configuration complete.'
Write-Log ('=' * 60)
exit 0
