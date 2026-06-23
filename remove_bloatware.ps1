#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Removes pre-installed Windows 11 apps that are not needed on most PCs.
.DESCRIPTION
    Removes both per-user and provisioned (system-wide) packages so the apps
    do not reinstall for new user accounts. Safe to run multiple times.
.NOTES
    Does NOT remove: Store, Edge, Settings, or any security component.
#>

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
$LogDir  = Join-Path $PSScriptRoot 'logs'
$LogFile = Join-Path $LogDir 'remove_bloatware.log'
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

# ----------------------------------------------------------------
# Bloatware list
# Package names accepted by Get-AppxPackage -Name (wildcards OK)
# ----------------------------------------------------------------
$Bloatware = @(
    # ── Xbox ──────────────────────────────────────────────────
    'Microsoft.XboxApp'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.Xbox.TCUI'
    'Microsoft.GamingApp'             # Xbox / Game Pass hub (Win 11)

    # ── Clipchamp ─────────────────────────────────────────────
    'Clipchamp.Clipchamp'

    # ── Microsoft Teams (consumer, not enterprise) ────────────
    'MicrosoftTeams'
    'Microsoft.Teams'
    'MSTeams'                         # Win 11 23H2 built-in chat

    # ── News / Weather / Maps ─────────────────────────────────
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Microsoft.WindowsMaps'

    # ── People / Skype ────────────────────────────────────────
    'Microsoft.People'
    'Microsoft.SkypeApp'

    # ── Mixed Reality Portal ──────────────────────────────────
    'Microsoft.MixedRealityPortal'

    # ── Solitaire ─────────────────────────────────────────────
    'Microsoft.MicrosoftSolitaireCollection'

    # ── Other rarely-wanted inbox apps ───────────────────────
    'Microsoft.ZuneMusic'             # Media Player (legacy)
    'Microsoft.ZuneVideo'             # Movies & TV
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'            # Tips
    'Microsoft.MicrosoftOfficeHub'    # Office hub (not Office itself)
    'Microsoft.Office.OneNote'        # Store OneNote (not desktop)
    'Microsoft.OneConnect'            # Paid Wi-Fi
    'Microsoft.Print3D'
    'Microsoft.Messaging'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.Todos'
    'Microsoft.Wallet'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.YourPhone'             # Phone Link
    'MicrosoftCorporationII.MicrosoftFamily'
)

# ----------------------------------------------------------------
# Removal helper
# ----------------------------------------------------------------
function Remove-AppSafe {
    param([string]$PackageName)

    $found = $false

    # 1. Per-user (current user)
    $userPkgs = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
    foreach ($pkg in $userPkgs) {
        $found = $true
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
            Write-Log "  Removed (user)   : $($pkg.PackageFullName)"
        } catch {
            Write-Log "  WARN remove user : $($pkg.PackageFullName) — $_" 'WARN'
        }
    }

    # 2. All users
    $allUserPkgs = Get-AppxPackage -AllUsers -Name $PackageName -ErrorAction SilentlyContinue
    foreach ($pkg in $allUserPkgs) {
        $found = $true
        try {
            Remove-AppxPackage -AllUsers -Package $pkg.PackageFullName -ErrorAction Stop
            Write-Log "  Removed (all)    : $($pkg.PackageFullName)"
        } catch {
            Write-Log "  WARN remove all  : $($pkg.PackageFullName) — $_" 'WARN'
        }
    }

    # 3. Provisioned (prevents reinstall for new accounts)
    $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $PackageName }
    foreach ($pkg in $provPkgs) {
        $found = $true
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
            Write-Log "  Removed (prov)   : $($pkg.PackageName)"
        } catch {
            Write-Log "  WARN remove prov : $($pkg.PackageName) — $_" 'WARN'
        }
    }

    return $found
}

# ----------------------------------------------------------------
# Main removal loop
# ----------------------------------------------------------------
Write-Log ('=' * 60)
Write-Log "Bloatware removal — targeting $($Bloatware.Count) packages"
Write-Log ('=' * 60)

$removed = 0
$skipped = 0

foreach ($name in $Bloatware) {
    Write-Log "──────────────────────────────────────────────────────"
    Write-Log "Package : $name"
    $wasFound = Remove-AppSafe -PackageName $name
    if ($wasFound) {
        $removed++
        Write-Log "Result  : Removed"
    } else {
        $skipped++
        Write-Log "Result  : Not present — skipped"
    }
}

# ----------------------------------------------------------------
# Block auto-reinstall of consumer experiences via policy
# ----------------------------------------------------------------
Write-Log ('=' * 60)
Write-Log 'Setting policy to block silent app reinstalls…'

$policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
Set-ItemProperty -Path $policyPath -Name 'DisableWindowsConsumerFeatures' -Value 1 -Type DWord -Force
Set-ItemProperty -Path $policyPath -Name 'DisableSoftLanding'             -Value 1 -Type DWord -Force
Write-Log 'Consumer features policy applied.'

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------
Write-Log ('=' * 60)
Write-Log "Done. Removed: $removed | Not found / skipped: $skipped"
Write-Log ('=' * 60)
exit 0
