#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures the Windows 11 Taskbar.
.DESCRIPTION
    Hides: Widgets, Search, Copilot, Chat (Teams), Task View.
    Left-aligns taskbar icons.
    Applies both user preferences and machine-level policies where appropriate.
    Safe to run multiple times.
#>

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
$LogDir  = Join-Path $PSScriptRoot 'logs'
$LogFile = Join-Path $LogDir 'taskbar_settings.log'
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
# Key paths
# ----------------------------------------------------------------
$Advanced      = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$Search        = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
$PeoplePath    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People'
$FeedsPolicy   = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'
$CopilotPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'
$DshPolicy     = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'

Write-Log ('=' * 60)
Write-Log 'Configuring Taskbar'
Write-Log ('=' * 60)

# ── Widgets (News & Interests / Dashboard) ────────────────────────
Write-Log '--- Widgets ---'
# User toggle
Set-Reg -Path $Advanced -Name 'TaskbarDa' -Value 0
# Policy (machine-wide, prevents group policy overrides)
Set-Reg -Path $DshPolicy -Name 'AllowNewsAndInterests' -Value 0
Set-Reg -Path $FeedsPolicy -Name 'EnableFeeds' -Value 0

# ── Search (box / icon) ───────────────────────────────────────────
Write-Log '--- Search Button ---'
# 0 = Hidden | 1 = Icon only | 2 = Search box | 3 = Search bar (23H2+)
Set-Reg -Path $Search   -Name 'SearchboxTaskbarMode' -Value 0
Set-Reg -Path $Advanced -Name 'SearchboxTaskbarMode' -Value 0

# ── Copilot ───────────────────────────────────────────────────────
Write-Log '--- Copilot Button ---'
Set-Reg -Path $Advanced     -Name 'ShowCopilotButton'     -Value 0
Set-Reg -Path $CopilotPolicy -Name 'TurnOffWindowsCopilot' -Value 1

# ── Chat / Teams ─────────────────────────────────────────────────
Write-Log '--- Chat (Teams) Button ---'
Set-Reg -Path $Advanced -Name 'TaskbarMn' -Value 0

# ── Task View ─────────────────────────────────────────────────────
Write-Log '--- Task View Button ---'
Set-Reg -Path $Advanced -Name 'ShowTaskViewButton' -Value 0

# ── Taskbar alignment (left) ──────────────────────────────────────
Write-Log '--- Taskbar Alignment ---'
# 0 = Left  |  1 = Center (Windows 11 default)
Set-Reg -Path $Advanced -Name 'TaskbarAl' -Value 1

# ── People button (legacy, still present on some builds) ──────────
Write-Log '--- People Button ---'
Set-Reg -Path $PeoplePath -Name 'PeopleBand' -Value 0

# ── Meet Now (legacy taskbar) ─────────────────────────────────────
Write-Log '--- Meet Now ---'
Set-Reg -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' `
         -Name 'HideSCAMeetNow' -Value 1

# ── Notification / Action Center ─────────────────────────────────
# Keep notification center visible (users need it); just remove clutter

# ── System tray: always show all icons (optional cleaner look) ────
Write-Log '--- System Tray ---'
# EnableAutoTray: 0 = always show all  |  1 = auto-hide excess (default)
Set-Reg -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' `
         -Name 'EnableAutoTray' -Value 1   # leave as default

# ── Auto-hide taskbar — OFF by default (users can toggle in Settings)
Write-Log '--- Auto-hide Taskbar ---'
# Leave TaskbarSizeMove / auto-hide at default; don't force-hide it

# ── Taskbar on multiple displays ─────────────────────────────────
Write-Log '--- Multi-Monitor Taskbar ---'
Set-Reg -Path $Advanced -Name 'MMTaskbarEnabled'    -Value 1  # show on all monitors
Set-Reg -Path $Advanced -Name 'MMTaskbarMode'       -Value 2  # show buttons for window's monitor
Set-Reg -Path $Advanced -Name 'MMTaskbarGlomLevel'  -Value 0  # combine when full

# ----------------------------------------------------------------
# Restart Explorer
# ----------------------------------------------------------------
Write-Log '--- Restarting Explorer to apply taskbar changes ---'
try {
    Stop-Process -Name 'explorer' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process 'explorer.exe'
    Write-Log '  Explorer restarted.'
} catch {
    Write-Log "  Could not restart Explorer: $_ — sign out to apply." 'WARN'
}

Write-Log ('=' * 60)
Write-Log 'Taskbar configuration complete.'
Write-Log ('=' * 60)
exit 0
