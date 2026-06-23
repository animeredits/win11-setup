#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Applies Windows 11 privacy hardening settings.
.DESCRIPTION
    - Disables telemetry and diagnostic data collection (sets to Security/0)
    - Stops and disables the DiagTrack (Connected User Experiences) service
    - Disables Advertising ID
    - Disables all content delivery / suggested-app subscriptions
    - Disables Cortana web search integration
    - Disables Activity History / Timeline uploads
    - Disables Windows Error Reporting
    - Disables lock-screen ads and spotlight
    - Disables app launch tracking and tailored experiences
    Does NOT disable Camera or Microphone system-wide (breaks video calls).
    Does NOT touch Windows Update or Defender.
    Safe to run multiple times.
#>

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
$LogDir  = Join-Path $PSScriptRoot 'logs'
$LogFile = Join-Path $LogDir 'privacy_tweaks.log'
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

function Disable-ServiceSafe {
    param([string]$Name, [string]$DisplayName)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        try {
            Stop-Service  -Name $Name -Force          -ErrorAction SilentlyContinue
            Set-Service   -Name $Name -StartupType Disabled -ErrorAction Stop
            Write-Log "  Disabled service : $DisplayName ($Name)"
        } catch {
            Write-Log "  WARN service $Name : $_" 'WARN'
        }
    } else {
        Write-Log "  Service not present : $Name (skipped)"
    }
}

Write-Log ('=' * 60)
Write-Log 'Privacy Tweaks'
Write-Log ('=' * 60)

# ================================================================
# 1. Telemetry
# ================================================================
Write-Log '--- Telemetry ---'

# Policy (strongest — takes effect even on Pro)
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'              0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'MaxTelemetryAllowed'         0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DisableOneSettingsDownloads' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1

# Service level (HKLM current user fallback)
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0

# Services that phone home
Disable-ServiceSafe 'DiagTrack'       'Connected User Experiences and Telemetry'
Disable-ServiceSafe 'dmwappushservice' 'Device Management WAP Push Message Routing'
Disable-ServiceSafe 'PcaSvc'          'Program Compatibility Assistant'
Disable-ServiceSafe 'WerSvc'          'Windows Error Reporting'

# ================================================================
# 2. Advertising ID
# ================================================================
Write-Log '--- Advertising ID ---'
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled'              0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'       'DisabledByGroupPolicy' 1

# ================================================================
# 3. Content Delivery Manager (suggested apps, lock-screen ads, etc.)
# ================================================================
Write-Log '--- Content Delivery / Suggested Apps ---'
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

$cdmKeys = @{
    'ContentDeliveryAllowed'           = 0
    'FeatureManagementEnabled'         = 0
    'OemPreInstalledAppsEnabled'       = 0
    'PreInstalledAppsEnabled'          = 0
    'PreInstalledAppsEverEnabled'      = 0
    'RotatingLockScreenEnabled'        = 0
    'RotatingLockScreenOverlayEnabled' = 0
    'SilentInstalledAppsEnabled'       = 0
    'SoftLandingEnabled'               = 0
    'SystemPaneSuggestionsEnabled'     = 0
    'SubscribedContentEnabled'         = 0
    # individual subscription IDs
    'SubscribedContent-202914Enabled'  = 0
    'SubscribedContent-280810Enabled'  = 0
    'SubscribedContent-280811Enabled'  = 0
    'SubscribedContent-280815Enabled'  = 0
    'SubscribedContent-310091Enabled'  = 0
    'SubscribedContent-310092Enabled'  = 0
    'SubscribedContent-310093Enabled'  = 0
    'SubscribedContent-314381Enabled'  = 0
    'SubscribedContent-314559Enabled'  = 0
    'SubscribedContent-314563Enabled'  = 0
    'SubscribedContent-338380Enabled'  = 0
    'SubscribedContent-338381Enabled'  = 0
    'SubscribedContent-338382Enabled'  = 0
    'SubscribedContent-338386Enabled'  = 0
    'SubscribedContent-338387Enabled'  = 0
    'SubscribedContent-338388Enabled'  = 0
    'SubscribedContent-338389Enabled'  = 0
    'SubscribedContent-338393Enabled'  = 0
    'SubscribedContent-353694Enabled'  = 0
    'SubscribedContent-353696Enabled'  = 0
    'SubscribedContent-353698Enabled'  = 0
    'SubscribedContent-88000044Enabled' = 0
    'SubscribedContent-88000105Enabled' = 0
    'SubscribedContent-88000161Enabled' = 0
    'SubscribedContent-88000162Enabled' = 0
    'SubscribedContent-88000163Enabled' = 0
    'SubscribedContent-88000164Enabled' = 0
    'SubscribedContent-88000165Enabled' = 0
    'SubscribedContent-88000166Enabled' = 0
}

foreach ($kv in $cdmKeys.GetEnumerator()) {
    Set-Reg -Path $cdm -Name $kv.Key -Value $kv.Value
}

# Machine-level consumer features policy
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding'             1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent'   1

# ================================================================
# 4. Cortana / Web Search integration
# ================================================================
Write-Log '--- Cortana / Web Search ---'
$ws = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
Set-Reg $ws 'AllowCortana'              0
Set-Reg $ws 'AllowCortanaAboveLock'     0
Set-Reg $ws 'AllowSearchToUseLocation'  0
Set-Reg $ws 'DisableWebSearch'          1
Set-Reg $ws 'ConnectedSearchUseWeb'     0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent'    0

# ================================================================
# 5. Activity History / Timeline
# ================================================================
Write-Log '--- Activity History ---'
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed'    0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities'  0

# ================================================================
# 6. Windows Error Reporting
# ================================================================
Write-Log '--- Windows Error Reporting ---'
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled'            1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'DontSendAdditionalData' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'Disabled'   1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting' 'DontSendAdditionalData' 1

# ================================================================
# 7. Feedback requests
# ================================================================
Write-Log '--- Feedback Requests ---'
Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'PeriodInNanoSeconds'  0

# ================================================================
# 8. Tailored Experiences
# ================================================================
Write-Log '--- Tailored Experiences ---'
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' `
         'TailoredExperiencesWithDiagnosticDataEnabled' 0

# ================================================================
# 9. Online Speech Recognition
# ================================================================
Write-Log '--- Online Speech Recognition ---'
Set-Reg 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 0

# ================================================================
# 10. Location (restrict by default; user can grant per-app)
# ================================================================
Write-Log '--- Location Access ---'
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' `
         'Value' 'Deny' 'String'

# ================================================================
# 11. Diagnostic Data Viewer storage
# ================================================================
Write-Log '--- Diagnostic Event Transcript ---'
$dtKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey'
Set-Reg $dtKey 'EnableEventTranscript' 0

# ================================================================
# 12. Defender notification noise (Defender stays ON)
# ================================================================
Write-Log '--- Defender Notification Noise (keeping Defender enabled) ---'
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications' `
         'DisableEnhancedNotifications' 1

Write-Log ('=' * 60)
Write-Log 'Privacy tweaks applied.'
Write-Log ('=' * 60)
exit 0
