#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs optional Windows features: .NET 3.5, Hyper-V, Windows Sandbox, WSL2.
.DESCRIPTION
    Edition-aware: reads the real EditionID from the registry (Core/CoreSingleLanguage
    = Home, Professional, ProfessionalWorkstation, Enterprise, Education, ServerRdsh,
    etc.) rather than guessing from the display caption, so Home-edition machines get
    a clear, accurate explanation instead of a generic DISM failure.

    Each feature is checked first — already-enabled ones are skipped.
    Hyper-V and Windows Sandbox require Pro-or-better AND CPU virtualisation enabled
    in firmware; on Home edition these features don't exist in the image at all (not
    just disabled), so this script detects that up front and explains the alternative
    (WSL2, which works on every edition; or third-party hypervisors for full VMs).

    Safe to run multiple times.
.NOTES
    Exit code 0 = done, no restart needed
    Exit code 2 = done, restart required to finish installation
#>

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
$LogDir  = Join-Path $PSScriptRoot 'logs'
$LogFile = Join-Path $LogDir 'windows_features.log'
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }

$script:RebootNeeded = $false

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

# ----------------------------------------------------------------
# Feature enable helper
# ----------------------------------------------------------------
function Enable-Feature {
    param([string]$Name, [string]$Label)

    Write-Log "──────────────────────────────────────────────────────"
    Write-Log "Feature : $Label ($Name)"

    try {
        $feat = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop
    } catch {
        Write-Log "  WARN : Cannot query feature '$Name' — $_" 'WARN'
        return $false
    }

    if ($feat.State -eq 'Enabled') {
        Write-Log "  Status  : Already enabled — skipped."
        return $true
    }

    Write-Log "  Status  : $($feat.State) — enabling…"

    try {
        $result = Enable-WindowsOptionalFeature `
            -Online          `
            -FeatureName $Name `
            -All             `
            -NoRestart       `
            -ErrorAction Stop

        if ($result.RestartNeeded) {
            Write-Log "  Result  : Enabled (restart required)."
            $script:RebootNeeded = $true
        } else {
            Write-Log "  Result  : Enabled (no restart needed)."
        }
        return $true
    } catch {
        Write-Log "  WARN : Could not enable '$Name' — $_" 'WARN'
        return $false
    }
}

# ----------------------------------------------------------------
# Edition detection — registry EditionID is far more reliable for
# branching logic than parsing the free-text Caption string.
# ----------------------------------------------------------------
function Get-WindowsEditionInfo {
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

    $editionId = if ($cv.EditionID) { $cv.EditionID } else { 'Unknown' }
    $caption   = if ($os.Caption)   { $os.Caption }   else { 'Unknown Windows' }

    # Tiers, from most to least capable, based on the real EditionID values
    # Microsoft actually ships (not the marketing name):
    #   Home        : Core, CoreSingleLanguage, CoreCountrySpecific, CoreN
    #   Pro         : Professional, ProfessionalN, ProfessionalEducation,
    #                 ProfessionalWorkstation, ProfessionalSingleLanguage
    #   Enterprise  : Enterprise, EnterpriseN, EnterpriseS, ServerRdsh, IoTEnterprise
    #   Education   : Education, EducationN
    $tier = switch -Regex ($editionId) {
        'Core'                     { 'Home';        break }
        'ProfessionalWorkstation'  { 'Workstation';  break }
        'Professional|CoreCountrySpecific'  { 'Pro';        break }
        'Enterprise|ServerRdsh|IoTEnterprise' { 'Enterprise'; break }
        'Education'                { 'Education';   break }
        default                    { 'Unknown' }
    }

    [pscustomobject]@{
        EditionId = $editionId
        Caption   = $caption
        Tier      = $tier
        # Hyper-V / Sandbox require Pro-or-better — Home cannot install them at all
        SupportsHyperV = $tier -in @('Pro', 'Workstation', 'Enterprise', 'Education')
    }
}

function Test-VirtualisationEnabled {
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cpu -and $cpu.VirtualizationFirmwareEnabled -eq $true) { return $true }

    $si = systeminfo 2>&1
    if ($si -match 'VM Monitor Mode Extensions:\s+Yes' -or
        $si -match 'Virtualization Enabled In Firmware:\s+Yes') {
        return $true
    }
    return $false
}

Write-Log ('=' * 60)
Write-Log 'Optional Windows Features'
Write-Log ('=' * 60)

$edition = Get-WindowsEditionInfo
$virtOk  = Test-VirtualisationEnabled

Write-Log "Windows edition  : $($edition.Caption)"
Write-Log "EditionID        : $($edition.EditionId)"
Write-Log "Capability tier  : $($edition.Tier)"
Write-Log "Virtualisation   : $(if ($virtOk) { 'Enabled in firmware' } else { 'NOT detected / not enabled in BIOS' })"
Write-Log ""

if ($edition.Tier -eq 'Home') {
    Write-Log '─────────────────────────────────────────────────────────' 
    Write-Log 'NOTE: Windows 11 HOME edition detected.'
    Write-Log '  Hyper-V and Windows Sandbox are not present in the Home'
    Write-Log '  image at all (this is a Microsoft licensing limit, not a'
    Write-Log '  setting) — enabling them is not possible without upgrading'
    Write-Log '  to Pro. WSL2 (Linux subsystem) works fine on Home and will'
    Write-Log '  still be installed below. For full VMs on Home, consider a'
    Write-Log '  third-party hypervisor such as VirtualBox or VMware'
    Write-Log '  Workstation Player, or run: changepk.exe to upgrade to Pro.'
    Write-Log '─────────────────────────────────────────────────────────'
}

# ================================================================
# .NET Framework 3.5
# (Needed by many legacy apps and some installers — every edition)
# ================================================================
Write-Log '=== .NET Framework 3.5 ==='
Enable-Feature -Name 'NetFx3' -Label '.NET Framework 3.5 (includes 2.0 and 3.0)'

# ================================================================
# Telnet Client — every edition
# ================================================================
Write-Log '=== Telnet Client ==='
Enable-Feature -Name 'TelnetClient' -Label 'Telnet Client'

# ================================================================
# Hyper-V
# ================================================================
Write-Log '=== Hyper-V ==='
if (-not $edition.SupportsHyperV) {
    Write-Log "  SKIP : Hyper-V is not available on Windows $($edition.Tier) edition (Pro/Enterprise/Education/Workstation required)." 'WARN'
} elseif (-not $virtOk) {
    Write-Log '  SKIP : CPU virtualisation not detected. Enable VT-x/AMD-V in BIOS/UEFI.' 'WARN'
} else {
    Enable-Feature -Name 'Microsoft-Hyper-V-All'       -Label 'Hyper-V (full)'
    Enable-Feature -Name 'Microsoft-Hyper-V'           -Label 'Hyper-V Platform'
    Enable-Feature -Name 'Microsoft-Hyper-V-Tools-All' -Label 'Hyper-V Management Tools'
}

# ================================================================
# Windows Sandbox
# ================================================================
Write-Log '=== Windows Sandbox ==='
if (-not $edition.SupportsHyperV) {
    Write-Log "  SKIP : Windows Sandbox is not available on Windows $($edition.Tier) edition (Pro/Enterprise/Education/Workstation required)." 'WARN'
} elseif (-not $virtOk) {
    Write-Log '  SKIP : CPU virtualisation not detected. Enable VT-x/AMD-V in BIOS/UEFI.' 'WARN'
} else {
    Enable-Feature -Name 'Containers-DisposableClientVM' -Label 'Windows Sandbox'
}

# ================================================================
# WSL2 — every edition, including Home
# ================================================================
Write-Log '=== WSL2 (available on every Windows 11 edition, including Home) ==='

if (-not $virtOk) {
    Write-Log '  SKIP : CPU virtualisation not detected. WSL2 requires VT-x/AMD-V in BIOS/UEFI.' 'WARN'
} else {
    $wslFeature = Get-WindowsOptionalFeature -Online `
                  -FeatureName 'Microsoft-Windows-Subsystem-Linux' -ErrorAction SilentlyContinue
    $vmFeature  = Get-WindowsOptionalFeature -Online `
                  -FeatureName 'VirtualMachinePlatform' -ErrorAction SilentlyContinue

    $wslAlreadyOn = ($wslFeature -and $wslFeature.State -eq 'Enabled')
    $vmAlreadyOn  = ($vmFeature  -and $vmFeature.State  -eq 'Enabled')

    if ($wslAlreadyOn -and $vmAlreadyOn) {
        Write-Log '  WSL and VirtualMachinePlatform already enabled.'

        $setV2 = wsl --set-default-version 2 2>&1
        Write-Log "  wsl --set-default-version 2 : $setV2"

        Write-Log '  Updating WSL kernel…'
        $upd = wsl --update 2>&1
        Write-Log "  $upd"

        $distros = wsl --list --quiet 2>&1
        if ($distros -and $distros.Trim() -ne '') {
            Write-Log "  Installed distros: $($distros -join ', ')"
        } else {
            Write-Log "  No Linux distro installed yet."
            Write-Log "  Run 'wsl --install -d Ubuntu' in a new terminal to get started."
        }
    } else {
        Write-Log '  Enabling WSL prerequisites…'
        Enable-Feature -Name 'Microsoft-Windows-Subsystem-Linux' -Label 'Windows Subsystem for Linux'
        Enable-Feature -Name 'VirtualMachinePlatform'            -Label 'Virtual Machine Platform'

        $taskScript = @'
@echo off
wsl --set-default-version 2
wsl --update
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "WSL2_PostBoot" /f 2>nul
exit /b 0
'@
        $taskPath = "$env:TEMP\wsl2_postboot.bat"
        $taskScript | Out-File -FilePath $taskPath -Encoding ASCII -Force

        try {
            $regRun = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
            Set-ItemProperty -Path $regRun -Name 'WSL2_PostBoot' `
                -Value "cmd /c `"$taskPath`"" -Type String -Force
            Write-Log "  Post-reboot WSL2 init registered at HKCU\...\Run\WSL2_PostBoot"
        } catch {
            Write-Log "  WARN: Could not register post-boot WSL2 task: $_" 'WARN'
            Write-Log "  After restarting, run manually: wsl --set-default-version 2" 'WARN'
        }

        Write-Log '  After restarting, install a distro with: wsl --install -d Ubuntu'
        $script:RebootNeeded = $true
    }
}

# ================================================================
# Summary
# ================================================================
Write-Log ('=' * 60)
Write-Log "Windows Features installation complete. (Edition tier: $($edition.Tier))"
if ($script:RebootNeeded) {
    Write-Log "RESTART REQUIRED to finish applying features." 'WARN'
    Write-Log ('=' * 60)
    exit 2
}
Write-Log ('=' * 60)
exit 0
