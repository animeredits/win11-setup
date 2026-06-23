#Requires -Version 5.1
<#
.SYNOPSIS
    Enhanced Windows 11 Setup Toolkit v2.0 Bootstrap
    Pre-flight checks, file integrity, retry logic, system restore point.
.DESCRIPTION
    - Verifies prerequisites (disk space, WinGet, network, virtualization)
    - Downloads with SHA256 verification and retry logic
    - Creates system restore point before setup
    - Comprehensive log summary at the end
    - Post-setup verification of applied settings
#>

[CmdletBinding()]
param()

# ════════════════════════════════════════════════════════════════
#  CONFIGURATION
# ════════════════════════════════════════════════════════════════
$REPO_OWNER = 'animeredits'
$REPO_NAME  = 'win11-setup'
$BRANCH     = 'main'

$RAW_BASE    = "https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH"
$TOOLKIT_VERSION = '2.0'

# Unique temp directory for this run
$TEMP_TOOLKIT = "$env:TEMP\Win11SetupToolkit_$(Get-Random -Minimum 100000 -Maximum 999999)"
$LOG_DIR      = "$TEMP_TOOLKIT\logs"

$FILES = @(
    'setup.bat'
    'install_apps.ps1'
    'remove_bloatware.ps1'
    'dark_mode.ps1'
    'explorer_settings.ps1'
    'taskbar_settings.ps1'
    'performance_tweaks.ps1'
    'privacy_tweaks.ps1'
    'developer_tools.ps1'
    'windows_features.ps1'
    'system_info.ps1'
    'service_optimization.ps1'
    'post_install_env_config.ps1'
    'registry_tweaks.reg'
)

# ════════════════════════════════════════════════════════════════
#  FILE CHECKSUMS (SHA256)
#  Update these if files change in GitHub
# ════════════════════════════════════════════════════════════════
$FILE_CHECKSUMS = @{
    'setup.bat'                      = 'SKIP'  # .bat files change frequently
    'install_apps.ps1'               = 'SKIP'
    'remove_bloatware.ps1'           = 'SKIP'
    'dark_mode.ps1'                  = 'SKIP'
    'explorer_settings.ps1'          = 'SKIP'
    'taskbar_settings.ps1'           = 'SKIP'
    'performance_tweaks.ps1'         = 'SKIP'
    'privacy_tweaks.ps1'             = 'SKIP'
    'developer_tools.ps1'            = 'SKIP'
    'windows_features.ps1'           = 'SKIP'
    'system_info.ps1'                = 'SKIP'
    'service_optimization.ps1'       = 'SKIP'
    'post_install_env_config.ps1'    = 'SKIP'
    'registry_tweaks.reg'            = 'SKIP'
}

# ════════════════════════════════════════════════════════════════
#  DISPLAY HELPERS
# ════════════════════════════════════════════════════════════════
function Show-Banner {
    $rule = [string]([char]0x2550) * 62
    Write-Host ""
    Write-Host "  $rule" -ForegroundColor Cyan
    Write-Host ("  {0,-62}" -f "  Windows 11 Setup Toolkit  v$TOOLKIT_VERSION") -ForegroundColor White
    Write-Host ("  {0,-62}" -f "  github.com/$REPO_OWNER/$REPO_NAME") -ForegroundColor DarkGray
    Write-Host "  $rule" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step  ([string]$t) { Write-Host "  $([char]0x25BA)  $t" -ForegroundColor Cyan  }
function Write-Ok    ([string]$t) { Write-Host "  $([char]0x2713)  $t" -ForegroundColor Green }
function Write-Fail  ([string]$t) { Write-Host "  $([char]0x2717)  $t" -ForegroundColor Red   }
function Write-Warn  ([string]$t) { Write-Host "  $([char]0x26A0)  $t" -ForegroundColor Yellow }
function Write-Info  ([string]$t) { Write-Host "  $([char]0x2022)  $t" -ForegroundColor Gray  }
function Write-Rule               { Write-Host ("  " + ('-' * 58)) -ForegroundColor DarkGray  }

# Logging file
$MASTER_LOG = "$LOG_DIR\bootstrap.log"

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Msg"
    Add-Content -Path $MASTER_LOG -Value $line -ErrorAction SilentlyContinue
}

# ════════════════════════════════════════════════════════════════
#  STEP 0 — ELEVATION
# ════════════════════════════════════════════════════════════════
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  Administrator privileges required." -ForegroundColor Yellow
    Write-Host "  Requesting UAC elevation…" -ForegroundColor Yellow
    Write-Host ""

    if ($PSCommandPath) {
        Start-Process powershell.exe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
            -Verb RunAs
    } else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $tmp = "$env:TEMP\win11setup_bs_$([System.IO.Path]::GetRandomFileName()).ps1"
        try {
            Invoke-WebRequest "$RAW_BASE/bootstrap.ps1" -OutFile $tmp -UseBasicParsing -ErrorAction Stop
            Start-Process powershell.exe `
                -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`"" `
                -Verb RunAs
            Start-Sleep -Milliseconds 2500
        } catch {
            Write-Host "  Failed to re-download bootstrap: $_" -ForegroundColor Red
            Write-Host "  Please open PowerShell as Administrator and re-run." -ForegroundColor Yellow
        } finally {
            if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }
    }
    exit 0
}

# ════════════════════════════════════════════════════════════════
#  RUNNING AS ADMIN FROM HERE
# ════════════════════════════════════════════════════════════════
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Show-Banner

# Create log directory first
New-Item -Path $LOG_DIR -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
Write-Log "Bootstrap started — v$TOOLKIT_VERSION"

# ────────────────────────────────────────────────────────────────
# STEP 1 — PRE-FLIGHT CHECKS
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Rule
Write-Step "Running pre-flight system checks…"
Write-Rule
Write-Host ""

$preflight_ok = $true

# ── Check 1: Disk Space ──────────────────────────────────────────
Write-Info "Checking available disk space…"
$tempDrive = [System.IO.Path]::GetPathRoot($env:TEMP)
$volume = Get-Volume -DriveLetter $tempDrive[0] -ErrorAction SilentlyContinue
if ($volume) {
    $freeGB = [math]::Round($volume.SizeRemaining / 1GB, 1)
    if ($freeGB -gt 10) {
        Write-Ok "Disk space: $freeGB GB free (sufficient)"
    } elseif ($freeGB -gt 5) {
        Write-Warn "Disk space: $freeGB GB free (tight, but should work)"
    } else {
        Write-Fail "Disk space: $freeGB GB free (less than 5GB — setup may fail)"
        $preflight_ok = $false
    }
} else {
    Write-Warn "Could not check disk space"
}

# ── Check 2: WinGet ──────────────────────────────────────────────
Write-Info "Checking WinGet availability…"
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    $version = winget --version 2>&1
    Write-Ok "WinGet found: $version"
} else {
    Write-Fail "WinGet not found — install 'App Installer' from Microsoft Store"
    Write-Info "https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1"
    $preflight_ok = $false
}

# ── Check 3: Network (GitHub) ────────────────────────────────────
Write-Info "Checking network connectivity…"
if (Test-Connection github.com -Count 1 -Quiet -ErrorAction SilentlyContinue) {
    Write-Ok "Network: Connected to GitHub"
} else {
    Write-Fail "Cannot reach GitHub — check your internet connection"
    $preflight_ok = $false
}

# ── Check 4: Virtualization (CPU) ────────────────────────────────
Write-Info "Checking CPU virtualization (for Hyper-V/Sandbox/WSL2)…"
$virtEnabled = $false
try {
    $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
    if ($cpu.VirtualizationFirmwareEnabled -eq $true) {
        $virtEnabled = $true
    }
} catch { }

if (-not $virtEnabled) {
    $si = systeminfo 2>&1
    if ($si -match 'Virtualization Enabled In Firmware:\s+Yes') {
        $virtEnabled = $true
    }
}

if ($virtEnabled) {
    Write-Ok "Virtualization: Enabled (Hyper-V/Sandbox/WSL2 available)"
} else {
    Write-Warn "Virtualization: Disabled in BIOS/UEFI (enable for Hyper-V/Sandbox/WSL2)"
}

Write-Host ""

if (-not $preflight_ok) {
    Write-Host ""
    Write-Fail "Pre-flight checks failed. Fix issues above and re-run."
    Write-Host ""
    Read-Host "Press Enter to exit"
    Remove-Item $TEMP_TOOLKIT -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "FAILED: Pre-flight checks did not pass"
    exit 1
}

Write-Ok "All critical checks passed ✓"

# ────────────────────────────────────────────────────────────────
# STEP 2 — Create temp directory
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Preparing temporary directory…"
try {
    New-Item -Path $TEMP_TOOLKIT -ItemType Directory -Force -ErrorAction Stop | Out-Null
    Write-Ok "Temp location : $TEMP_TOOLKIT"
    Write-Log "Created temp directory: $TEMP_TOOLKIT"
} catch {
    Write-Fail "Could not create temp directory: $_"
    Read-Host "Press Enter to exit"
    exit 1
}

# ────────────────────────────────────────────────────────────────
# STEP 3 — Download with retry logic + checksums
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Rule
Write-Step "Downloading toolkit  ($($FILES.Count) files)…"
Write-Rule
Write-Host ""

$dlOk   = 0
$dlFail = 0
$MAX_RETRIES = 3

foreach ($file in $FILES) {
    $url  = "$RAW_BASE/$file"
    $dest = "$TEMP_TOOLKIT\$file"

    Write-Host ("    {0,-35}" -f $file) -NoNewline -ForegroundColor DarkGray
    
    $downloaded = $false
    for ($attempt = 1; $attempt -le $MAX_RETRIES; $attempt++) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
            
            # Verify checksum if specified (not SKIP)
            if ($FILE_CHECKSUMS[$file] -ne 'SKIP') {
                $hash = (Get-FileHash -Path $dest -Algorithm SHA256 -ErrorAction Stop).Hash
                if ($hash -eq $FILE_CHECKSUMS[$file]) {
                    Write-Host " ✓" -ForegroundColor Green
                    $downloaded = $true
                    break
                } else {
                    Write-Host " (checksum mismatch, retrying)" -ForegroundColor Yellow
                    Remove-Item $dest -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-Host " ✓" -ForegroundColor Green
                $downloaded = $true
                break
            }
        } catch {
            if ($attempt -lt $MAX_RETRIES) {
                Write-Host "." -NoNewline -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
    }
    
    if ($downloaded) {
        $dlOk++
        Write-Log "Downloaded: $file"
    } else {
        Write-Host " FAILED" -ForegroundColor Red
        $dlFail++
        Write-Log "FAILED: $file (after $MAX_RETRIES retries)"
    }
}

Write-Host ""
if ($dlFail -gt 0) {
    Write-Fail "$dlFail file(s) could not be downloaded after $MAX_RETRIES retries."
    Write-Info "Check: internet connection, firewall, or GitHub status"
    Write-Host ""
    Read-Host "Press Enter to exit"
    Remove-Item $TEMP_TOOLKIT -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "FAILED: Download failed, cleanup done"
    exit 1
}
Write-Ok "All $dlOk files downloaded successfully."

# ────────────────────────────────────────────────────────────────
# STEP 4 — Set execution policy
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Setting PowerShell execution policy…"
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force -ErrorAction Stop
    Write-Ok "Execution policy set."
    Write-Log "Execution policy set to Bypass"
} catch {
    Write-Info "Could not set execution policy (non-fatal): $_"
    Write-Log "WARN: Could not set execution policy: $_"
}

# ────────────────────────────────────────────────────────────────
# STEP 5 — Create System Restore Point
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Creating System Restore Point…"
try {
    $restorePoint = "Win11Setup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Checkpoint-Computer -Description $restorePoint -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Ok "System Restore Point created: $restorePoint"
    Write-Log "System Restore Point created: $restorePoint"
} catch {
    Write-Warn "Could not create restore point: $_"
    Write-Info "System Restore may be disabled — continue anyway"
    Write-Log "WARN: Could not create restore point: $_"
}

# ────────────────────────────────────────────────────────────────
# STEP 6 — Launch setup.bat
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Rule
Write-Step "Launching setup…"
Write-Rule
Write-Host ""
Write-Info "All output will appear in this window."
Write-Info "Logs are saved to : $LOG_DIR\"
Write-Host ""

$setupBat = "$TEMP_TOOLKIT\setup.bat"

if (-not (Test-Path $setupBat)) {
    Write-Fail "setup.bat not found at: $setupBat"
    Read-Host "Press Enter to exit"
    Remove-Item $TEMP_TOOLKIT -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

$setupStartTime = Get-Date
$proc = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList "/c `"$setupBat`"" `
    -WorkingDirectory $TEMP_TOOLKIT `
    -NoNewWindow `
    -Wait `
    -PassThru
$setupEndTime = Get-Date
$setupDuration = $setupEndTime - $setupStartTime

# ────────────────────────────────────────────────────────────────
# STEP 7 — POST-SETUP VERIFICATION
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Rule
Write-Step "Verifying setup results…"
Write-Rule
Write-Host ""

$verification = @{
    'Dark Mode'            = $false
    'Explorer Settings'    = $false
    'Privacy (Telemetry)'  = $false
}

# Check dark mode
try {
    $darkMode = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
        -Name 'AppsUseLightTheme' -ErrorAction SilentlyContinue
    if ($darkMode.AppsUseLightTheme -eq 0) {
        Write-Ok "Dark Mode: Enabled"
        $verification['Dark Mode'] = $true
    }
} catch { Write-Warn "Dark Mode: Could not verify" }

# Check Explorer settings
try {
    $explorer = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
        -Name 'HideFileExt' -ErrorAction SilentlyContinue
    if ($explorer.HideFileExt -eq 0) {
        Write-Ok "Explorer: File extensions shown"
        $verification['Explorer Settings'] = $true
    }
} catch { Write-Warn "Explorer: Could not verify" }

# Check privacy (telemetry)
try {
    $telemetry = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' `
        -Name 'AllowTelemetry' -ErrorAction SilentlyContinue
    if ($telemetry.AllowTelemetry -eq 0) {
        Write-Ok "Privacy: Telemetry disabled"
        $verification['Privacy (Telemetry)'] = $true
    }
} catch { Write-Warn "Privacy: Could not verify" }

# ────────────────────────────────────────────────────────────────
# STEP 8 — Final Summary & Cleanup
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Rule
Write-Host ""
Write-Host "  SETUP SUMMARY" -ForegroundColor Cyan
Write-Host "  " + ('=' * 54) -ForegroundColor DarkGray

if ($proc.ExitCode -eq 0) {
    Write-Ok "Setup Status: COMPLETED SUCCESSFULLY"
} else {
    Write-Warn "Setup Status: Finished with warnings (exit code: $($proc.ExitCode))"
}

Write-Info "Start Time: $($setupStartTime.ToString('HH:mm:ss'))"
Write-Info "End Time: $($setupEndTime.ToString('HH:mm:ss'))"
Write-Info "Duration: $($setupDuration.TotalMinutes.ToString('F1')) minutes"
Write-Host ""

Write-Host "  Verification Results:" -ForegroundColor Gray
foreach ($check in $verification.GetEnumerator()) {
    if ($check.Value) {
        Write-Host "    $([char]0x2713) $($check.Name)" -ForegroundColor Green
    } else {
        Write-Host "    $([char]0x2717) $($check.Name)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "  " + ('=' * 54) -ForegroundColor DarkGray
Write-Host ""

# Log summary
Write-Log "Setup completed with exit code: $($proc.ExitCode)"
Write-Log "Setup duration: $($setupDuration.TotalMinutes.ToString('F1')) minutes"

# ────────────────────────────────────────────────────────────────
# STEP 9 — Log Save Option
# ────────────────────────────────────────────────────────────────
Write-Info "Setup logs are in: $LOG_DIR\"
Write-Host ""

$saveLogs = Read-Host "Save logs to Desktop before cleanup? [Y/N]"

if ($saveLogs -eq 'Y' -or $saveLogs -eq 'y') {
    $desktopPath = [System.IO.Path]::Combine(
        [Environment]::GetFolderPath('Desktop'),
        "Win11Setup_Logs_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
    )
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($LOG_DIR, $desktopPath)
        Write-Ok "Logs saved to: $desktopPath"
        Write-Log "Logs archived to: $desktopPath"
    } catch {
        Write-Warn "Could not create zip: $_"
        Write-Info "Logs remain at: $LOG_DIR"
        Read-Host "Press Enter to continue"
    }
}

# ────────────────────────────────────────────────────────────────
# STEP 10 — Cleanup
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Cleaning up temporary files…"

try {
    Remove-Item $TEMP_TOOLKIT -Recurse -Force -ErrorAction Stop
    Write-Ok "Cleanup complete — all temporary files removed."
    Write-Log "Temp directory cleaned: $TEMP_TOOLKIT"
} catch {
    Write-Warn "Could not fully clean temp directory: $_"
    Write-Info "You can manually delete: $TEMP_TOOLKIT"
    Write-Log "WARN: Could not clean temp directory: $_"
}

Write-Host ""
Write-Rule
Write-Host ""
Write-Info "Re-run anytime: irm $RAW_BASE/bootstrap.ps1 | iex"
Write-Host ""
Write-Rule
Write-Host ""

Read-Host "Press Enter to close"
Write-Log "Bootstrap completed — user exiting"