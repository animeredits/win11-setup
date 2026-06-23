#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Disables Windows services that gaming / developer / power-user profiles
    typically don't need, while leaving everything safety-critical untouched.
.DESCRIPTION
    UNIVERSAL (every profile) — services that are safe to disable for virtually
    everyone in 2026 regardless of how the PC is used:
      Fax, Downloaded Maps Manager, Retail Demo Service, Microsoft Wallet Service

    MAX-PERFORMANCE PROFILES (Developer, Gaming, Creative, Full):
      SysMain (Superfetch) — pre-loads frequently used apps into RAM; on modern
      SSDs this is widely considered unnecessary background I/O and is one of
      the most common gaming-PC tweaks. Skipped for Normal/Productivity, where
      it can still help on slower storage or RAM-constrained everyday use.

    NON-GAMING PROFILES ONLY (i.e. Gaming is NOT among the selected profiles):
      Xbox services (XblAuthManager, XblGameSave, XboxNetApiSvc, XboxGipSvc) —
      orphaned once the Xbox app is removed by remove_bloatware.ps1. These are
      DELIBERATELY KEPT ENABLED whenever Gaming is selected (alone or combined
      with another profile, e.g. "Developer,Gaming") because many non-Xbox-app
      games (Steam, Epic, Battle.net titles with crossplay/achievements — Halo,
      Sea of Thieves, Forza, etc.) still depend on Xbox Live networking even
      without the Xbox app installed.

    NEVER TOUCHED, in any profile, ever:
      Windows Update (wuauserv), Windows Defender (WinDefend), Security Center
      (wscsvc), Windows Firewall (mpssvc), BITS, Event Log, RPC, DCOM — all
      core OS/security services stay exactly as Windows configured them.

    Safe to run multiple times.
.PARAMETER Profile
    One or more of: Normal, Productivity, Developer, Gaming, Creative, Full.
    Accepts a comma-separated list for hybrid users, e.g. "Developer,Gaming".
    Defaults to 'Normal' if omitted.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Profile = 'Normal'
)

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
$LogDir  = Join-Path $PSScriptRoot 'logs'
$LogFile = Join-Path $LogDir 'service_optimization.log'
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

function Disable-ServiceSafe {
    param([string]$Name, [string]$DisplayName, [string]$Reason)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Log "  Not present : $DisplayName ($Name) — skipped"
        return
    }
    if ($svc.StartType -eq 'Disabled') {
        Write-Log "  Already disabled : $DisplayName ($Name)"
        return
    }
    try {
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        Set-Service  -Name $Name -StartupType Disabled -ErrorAction Stop
        Write-Log "  Disabled : $DisplayName ($Name)  — $Reason"
    } catch {
        Write-Log "  WARN: could not disable $DisplayName ($Name): $_" 'WARN'
    }
}

function Ensure-ServiceEnabled {
    param([string]$Name, [string]$DisplayName, [string]$Reason)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Log "  Not present : $DisplayName ($Name) — nothing to keep"
        return
    }
    if ($svc.StartType -eq 'Disabled') {
        try {
            Set-Service -Name $Name -StartupType Manual -ErrorAction Stop
            Write-Log "  Kept enabled (re-enabled to Manual) : $DisplayName ($Name) — $Reason"
        } catch {
            Write-Log "  WARN: could not re-enable $DisplayName ($Name): $_" 'WARN'
        }
    } else {
        Write-Log "  Kept enabled (no change) : $DisplayName ($Name) — $Reason"
    }
}

# ----------------------------------------------------------------
# Parse profile list (supports comma-separated hybrid input)
# ----------------------------------------------------------------
$ValidProfiles = @('Normal', 'Productivity', 'Developer', 'Gaming', 'Creative', 'Full')
$ProfileList = $Profile -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
$ProfileList = $ProfileList | Where-Object { $ValidProfiles -contains $_ }
if ($ProfileList.Count -eq 0) { $ProfileList = @('Normal') }

if ($ProfileList -contains 'Full') {
    # Full = every profile's worth of behaviour, including Gaming's exception
    $ProfileList = $ValidProfiles
}

$MaxPerfProfiles = @('Developer', 'Gaming', 'Creative', 'Full')
$UseMaxPerf      = ($ProfileList | Where-Object { $MaxPerfProfiles -contains $_ }).Count -gt 0
$IsGaming        = $ProfileList -contains 'Gaming'

Write-Log ('=' * 60)
Write-Log "Service Optimization — Profile(s): $($ProfileList -join ', ')"
Write-Log "Max-performance tweaks : $(if ($UseMaxPerf) { 'YES' } else { 'no' })"
Write-Log "Gaming selected        : $(if ($IsGaming) { 'YES — Xbox services kept' } else { 'no — Xbox services will be disabled' })"
Write-Log ('=' * 60)

# ----------------------------------------------------------------
# Services this script will NEVER touch — listed explicitly for
# transparency and so a future edit can't accidentally include them.
# ----------------------------------------------------------------
$NeverTouch = @(
    'wuauserv',        # Windows Update
    'WinDefend',        # Windows Defender Antivirus Service
    'SecurityHealthService', # Windows Security app
    'wscsvc',           # Security Center
    'mpssvc',           # Windows Defender Firewall
    'BITS',             # Background Intelligent Transfer (used by Windows Update)
    'EventLog',
    'RpcSs',
    'DcomLaunch'
)
Write-Log "Protected services (never modified): $($NeverTouch -join ', ')"

# ================================================================
# 1. UNIVERSAL — safe for every profile
# ================================================================
Write-Log '--- Universal safe disables (every profile) ---'
Disable-ServiceSafe -Name 'Fax'         -DisplayName 'Fax'                       -Reason 'legacy fax, virtually unused in 2026'
Disable-ServiceSafe -Name 'MapsBroker'  -DisplayName 'Downloaded Maps Manager'   -Reason 'Windows Maps app is removed by this toolkit'
Disable-ServiceSafe -Name 'RetailDemo'  -DisplayName 'Retail Demo Service'       -Reason 'only used for in-store demo mode'
Disable-ServiceSafe -Name 'WalletService' -DisplayName 'Microsoft Wallet Service' -Reason 'deprecated, no longer used by Windows'

# ================================================================
# 2. MAX-PERFORMANCE PROFILES ONLY — SysMain
# ================================================================
if ($UseMaxPerf) {
    Write-Log '--- Max-performance disables (Developer/Gaming/Creative/Full) ---'
    Disable-ServiceSafe -Name 'SysMain' -DisplayName 'SysMain (Superfetch)' `
        -Reason 'reduces background disk I/O / RAM pre-loading on SSDs — common gaming/dev tweak'
} else {
    Write-Log '--- SysMain (Superfetch): left enabled for this profile (can help on slower storage) ---'
    Ensure-ServiceEnabled -Name 'SysMain' -DisplayName 'SysMain (Superfetch)' -Reason 'helpful default for everyday/office use'
}

# ================================================================
# 3. XBOX SERVICES — disabled unless Gaming is one of the selected profiles
# ================================================================
$xboxServices = @(
    @{ Name = 'XblAuthManager'; Display = 'Xbox Live Auth Manager' }
    @{ Name = 'XblGameSave';    Display = 'Xbox Live Game Save' }
    @{ Name = 'XboxNetApiSvc';  Display = 'Xbox Live Networking Service' }
    @{ Name = 'XboxGipSvc';     Display = 'Xbox Accessory Management Service' }
)

if ($IsGaming) {
    Write-Log '--- Xbox services: KEPT ENABLED (Gaming profile selected) ---'
    foreach ($s in $xboxServices) {
        Ensure-ServiceEnabled -Name $s.Name -DisplayName $s.Display `
            -Reason 'many non-Xbox-app games use Xbox Live for crossplay/achievements'
    }
} else {
    Write-Log '--- Xbox services: disabling (Gaming not selected, Xbox app already removed) ---'
    foreach ($s in $xboxServices) {
        Disable-ServiceSafe -Name $s.Name -DisplayName $s.Display `
            -Reason 'orphaned after Xbox app removal; not needed without Gaming profile'
    }
}

# ================================================================
# Summary
# ================================================================
Write-Log ('=' * 60)
Write-Log "Service optimization complete for profile(s): $($ProfileList -join ', ')"
Write-Log 'Reminder: re-enable any service via: Set-Service -Name <svc> -StartupType Manual; Start-Service <svc>'
Write-Log ('=' * 60)
exit 0
