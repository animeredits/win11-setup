#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Applies Windows 11 performance optimisations, tailored by usage profile.
.DESCRIPTION
    UNIVERSAL (every profile):
      - Power plan: Ultimate Performance for performance-hungry profiles,
        High Performance for everyday profiles
      - Disables hibernation (saves GBs of disk space)
      - Visual effects tuned to a balanced custom set
      - Memory management tuning (kernel paging, prefetch)
      - Foreground process priority boost
      - NTFS: disables last-access timestamps and 8.3 name creation
      - Disables startup delay
      - SSD detection / Storage Optimizer check

    MAX-PERFORMANCE PROFILES ONLY (Developer, Gaming, Creative, Full):
      - Hardware Accelerated GPU Scheduling (HAGS)
      - Multimedia system profile tuned for low-latency (SystemResponsiveness=0,
        network throttling disabled, foreground task GPU/CPU priority boost)
      - Game Mode auto-enabled, Game DVR/Game Bar capture disabled

    DOES NOT disable Windows Update or Windows Defender.
    Safe to run multiple times.
.PARAMETER Profile
    Normal | Productivity | Developer | Gaming | Creative | Full
    Controls which power plan is selected and whether the low-latency
    multimedia/GPU tweaks are applied. Defaults to 'Normal' if omitted.
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Normal', 'Productivity', 'Developer', 'Gaming', 'Creative', 'Full')]
    [string]$Profile = 'Normal'
)

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
$LogDir  = Join-Path $PSScriptRoot 'logs'
$LogFile = Join-Path $LogDir 'performance_tweaks.log'
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

function Set-Reg {
    param([string]$Path, [string]$Name, [object]$Value, [string]$Type = 'DWord')
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    try {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        Write-Log "  SET  $Name = $Value"
    } catch {
        Write-Log "  WARN $Name : $_" 'WARN'
    }
}

# ----------------------------------------------------------------
# Profile gating
# ----------------------------------------------------------------
# Profiles that benefit from the most aggressive low-latency / GPU tweaks.
# Normal & Productivity machines stay on safer, quieter, more battery-friendly
# defaults; they still get every UNIVERSAL tweak below.
$MaxPerfProfiles = @('Developer', 'Gaming', 'Creative', 'Full')
$UseMaxPerf      = $MaxPerfProfiles -contains $Profile

Write-Log ('=' * 60)
Write-Log "Performance Tweaks — Profile: $Profile"
Write-Log "Max-performance tweak set : $(if ($UseMaxPerf) { 'ENABLED' } else { 'skipped (not needed for this profile)' })"
Write-Log ('=' * 60)

# ================================================================
# 1. Power plan — Ultimate (max-perf profiles) or High Performance (everyday)
# ================================================================
Write-Log '--- Power Plan ---'

$ultimateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$highPerfGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'

if ($UseMaxPerf) {
    Write-Log "  Profile '$Profile' requests maximum performance — targeting Ultimate Performance."

    $schemeList = powercfg /list 2>&1
    if ($schemeList -notmatch $ultimateGuid) {
        Write-Log '  Ultimate Performance not present — duplicating scheme…'
        $out = powercfg -duplicatescheme $ultimateGuid 2>&1
        Write-Log "  $out"
    }
    $schemeList = powercfg /list 2>&1

    if ($schemeList -match $ultimateGuid) {
        powercfg /setactive $ultimateGuid | Out-Null
        Write-Log '  Active plan : Ultimate Performance'
    } elseif ($schemeList -match $highPerfGuid) {
        powercfg /setactive $highPerfGuid | Out-Null
        Write-Log '  Active plan : High Performance (Ultimate not available on this SKU)'
    } else {
        Write-Log '  WARN: Neither Ultimate nor High Performance plan found. Check powercfg /list.' 'WARN'
    }
} else {
    Write-Log "  Profile '$Profile' uses everyday performance — targeting High Performance."

    $schemeList = powercfg /list 2>&1
    if ($schemeList -match $highPerfGuid) {
        powercfg /setactive $highPerfGuid | Out-Null
        Write-Log '  Active plan : High Performance'
    } else {
        Write-Log '  WARN: High Performance plan not found. Check powercfg /list.' 'WARN'
    }
}

# AC timeouts: display off after 15 min, sleep/hibernate never
powercfg /change monitor-timeout-ac 15  2>&1 | Out-Null
powercfg /change standby-timeout-ac 0   2>&1 | Out-Null
powercfg /change hibernate-timeout-ac 0 2>&1 | Out-Null
Write-Log '  Sleep (AC) = never | Hibernate (AC) = never | Monitor (AC) = 15 min'

# ================================================================
# 2. Disable Hibernation (reclaim hiberfil.sys — often 4-16 GB) — universal
# ================================================================
Write-Log '--- Hibernate (universal) ---'
$result = powercfg /h off 2>&1
Write-Log "  Hibernation disabled. $result"

# ================================================================
# 3. Visual Effects — custom, keep useful ones — universal
# ================================================================
Write-Log '--- Visual Effects (universal) ---'

Set-Reg -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' `
         -Name 'VisualFXSetting' -Value 3

$upMask = [byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)
Set-ItemProperty 'HKCU:\Control Panel\Desktop' `
    -Name 'UserPreferencesMask' -Value $upMask -Type Binary -Force -ErrorAction SilentlyContinue
Write-Log '  UserPreferencesMask set (balanced custom effects).'

Set-Reg -Path 'HKCU:\Control Panel\Desktop' -Name 'FontSmoothing'     -Value '2' -Type String
Set-Reg -Path 'HKCU:\Control Panel\Desktop' -Name 'FontSmoothingType' -Value 2
Set-Reg -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay'     -Value '0' -Type String
Set-Reg -Path 'HKCU:\Control Panel\Desktop' -Name 'DragFullWindows'   -Value '1' -Type String
Set-Reg -Path 'HKCU:\SOFTWARE\Microsoft\Windows\DWM' -Name 'EnableAeroPeek' -Value 0

# ================================================================
# 4. Hardware Accelerated GPU Scheduling (HAGS) — max-perf profiles only
# ================================================================
if ($UseMaxPerf) {
    Write-Log '--- Hardware Accelerated GPU Scheduling (max-perf profiles) ---'
    Set-Reg -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Value 2
    Write-Log '  HAGS enabled (Value=2). GPU driver must support WDDM 2.7+.'
} else {
    Write-Log '--- Hardware Accelerated GPU Scheduling: skipped for this profile (left at Windows default) ---'
}

# ================================================================
# 5. Multimedia / Game profile — max-perf profiles only
# ================================================================
if ($UseMaxPerf) {
    Write-Log '--- Multimedia System Profile (max-perf profiles) ---'
    $mmBase = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    Set-Reg -Path $mmBase -Name 'SystemResponsiveness'   -Value 0          # 0=best for apps, 20=default
    Set-Reg -Path $mmBase -Name 'NetworkThrottlingIndex' -Value 4294967295 # 0xFFFFFFFF = disable throttle

    $mmGames = "$mmBase\Tasks\Games"
    if (-not (Test-Path $mmGames)) { New-Item -Path $mmGames -Force | Out-Null }
    Set-Reg -Path $mmGames -Name 'GPU Priority'        -Value 8
    Set-Reg -Path $mmGames -Name 'Priority'            -Value 6
    Set-Reg -Path $mmGames -Name 'Scheduling Category' -Value 'High' -Type String
    Set-Reg -Path $mmGames -Name 'SFIO Priority'       -Value 'High' -Type String
} else {
    Write-Log '--- Multimedia System Profile: left at Windows default for this profile ---'
}

# ================================================================
# 6. Memory Management — universal
# ================================================================
Write-Log '--- Memory Management (universal) ---'
$memPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
Set-Reg -Path $memPath -Name 'ClearPageFileAtShutdown' -Value 0   # slow if enabled
Set-Reg -Path $memPath -Name 'DisablePagingExecutive'  -Value 1   # keep kernel in RAM
Set-Reg -Path $memPath -Name 'LargeSystemCache'        -Value 0   # workstation mode

$prefetch = "$memPath\PrefetchParameters"
Set-Reg -Path $prefetch -Name 'EnablePrefetcher' -Value 3   # 3=all
Set-Reg -Path $prefetch -Name 'EnableSuperfetch' -Value 3

# ================================================================
# 7. Processor scheduling — universal
# ================================================================
Write-Log '--- Processor Scheduling (universal) ---'
Set-Reg -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' `
         -Name 'Win32PrioritySeparation' -Value 26

# ================================================================
# 8. NTFS Tweaks — universal
# ================================================================
Write-Log '--- NTFS Tweaks (universal) ---'
$laResult = fsutil behavior set DisableLastAccess 1 2>&1
Write-Log "  DisableLastAccess : $laResult"
$sfResult = fsutil behavior set Disable8dot3 1 2>&1
Write-Log "  Disable8dot3 : $sfResult"

# ================================================================
# 9. Game Mode / Game DVR — max-perf profiles only
# ================================================================
if ($UseMaxPerf) {
    Write-Log '--- Game Mode / Game DVR (max-perf profiles) ---'
    $gameBar = 'HKCU:\SOFTWARE\Microsoft\GameBar'
    if (-not (Test-Path $gameBar)) { New-Item -Path $gameBar -Force | Out-Null }
    Set-Reg -Path $gameBar -Name 'AutoGameModeEnabled' -Value 1
    Set-Reg -Path $gameBar -Name 'AllowAutoGameMode'   -Value 1

    Set-Reg -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0
    Set-Reg -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0
} else {
    Write-Log '--- Game Mode / Game DVR: left at Windows default for this profile ---'
}

# ================================================================
# 10. Startup delay — universal
# ================================================================
Write-Log '--- Startup Delay (universal) ---'
$serialize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
if (-not (Test-Path $serialize)) { New-Item -Path $serialize -Force | Out-Null }
Set-Reg -Path $serialize -Name 'StartupDelayInMSec' -Value 0

# ================================================================
# 11. SSD detection and optimisation hint — universal
# ================================================================
Write-Log '--- Storage (universal) ---'
$ssd = Get-PhysicalDisk -ErrorAction SilentlyContinue |
       Where-Object { $_.MediaType -eq 'SSD' } |
       Select-Object -First 1
if ($ssd) {
    Write-Log "  SSD detected : $($ssd.FriendlyName)"
    Write-Log '  Trim is handled automatically by Windows Storage Optimizer.'
    $task = Get-ScheduledTask -TaskName 'ScheduledDefrag' -ErrorAction SilentlyContinue
    if ($task -and $task.State -ne 'Ready') {
        Enable-ScheduledTask -TaskName 'ScheduledDefrag' -ErrorAction SilentlyContinue | Out-Null
        Write-Log '  Storage Optimizer task re-enabled.'
    }
} else {
    Write-Log '  No SSD detected (or mixed) — standard settings apply.'
}

Write-Log ('=' * 60)
Write-Log "Performance tweaks applied for profile: $Profile"
Write-Log ('=' * 60)
exit 0
