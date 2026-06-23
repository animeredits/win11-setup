#Requires -Version 5.1
<#
.SYNOPSIS
    One-command bootstrap for Windows 11 Setup Toolkit.
.DESCRIPTION
    Downloads the full toolkit from GitHub, handles UAC elevation automatically,
    then launches setup.bat. Re-running always fetches the latest version.

.NOTES
    Install path : %LOCALAPPDATA%\Win11SetupToolkit
    Re-runnable  : Yes — all scripts are idempotent
#>

[CmdletBinding()]
param()

# ════════════════════════════════════════════════════════════════
#  CONFIGURATION  ← Edit these two lines before pushing to GitHub
# ════════════════════════════════════════════════════════════════
$REPO_OWNER = 'animeredits'   # ← replace with your GitHub username
$REPO_NAME  = 'win11-setup'            # ← replace if you used a different repo name
$BRANCH     = 'main'

# ════════════════════════════════════════════════════════════════
#  DERIVED CONSTANTS  (no need to change below this line)
# ════════════════════════════════════════════════════════════════
$RAW_BASE    = "https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH"
$INSTALL_DIR = "$env:LOCALAPPDATA\Win11SetupToolkit"
$TOOLKIT_VERSION = '2.0'

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
    'registry_tweaks.reg'
)

# ════════════════════════════════════════════════════════════════
#  DISPLAY HELPERS
# ════════════════════════════════════════════════════════════════
function Show-Banner {
    $rule = [string]([char]0x2550) * 62   # ══════…
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
function Write-Info  ([string]$t) { Write-Host "  $([char]0x2022)  $t" -ForegroundColor Gray  }
function Write-Rule               { Write-Host ("  " + ('-' * 58)) -ForegroundColor DarkGray  }

# ════════════════════════════════════════════════════════════════
#  STEP 0 — ELEVATION
#  If not admin: re-launch as admin (handles both irm|iex and file modes)
# ════════════════════════════════════════════════════════════════
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  Administrator privileges required." -ForegroundColor Yellow
    Write-Host "  Requesting UAC elevation…" -ForegroundColor Yellow
    Write-Host ""

    if ($PSCommandPath) {
        # Script was saved to disk (e.g. -File bootstrap.ps1) — relaunch the same file
        Start-Process powershell.exe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
            -Verb RunAs
    } else {
        # Running via irm | iex — re-download to temp, then relaunch from disk
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $tmp = "$env:TEMP\win11setup_bs_$([System.IO.Path]::GetRandomFileName()).ps1"
        try {
            Invoke-WebRequest "$RAW_BASE/bootstrap.ps1" -OutFile $tmp -UseBasicParsing -ErrorAction Stop
            Start-Process powershell.exe `
                -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`"" `
                -Verb RunAs
            Start-Sleep -Milliseconds 2500
        } catch {
            Write-Host "  Failed to re-download bootstrap for elevation: $_" -ForegroundColor Red
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

# ────────────────────────────────────────────────────────────────
# STEP 1 — Create local install directory
# ────────────────────────────────────────────────────────────────
Write-Step "Preparing install directory…"
try {
    New-Item -Path $INSTALL_DIR        -ItemType Directory -Force -ErrorAction Stop | Out-Null
    New-Item -Path "$INSTALL_DIR\logs" -ItemType Directory -Force -ErrorAction Stop | Out-Null
    Write-Ok "Location : $INSTALL_DIR"
} catch {
    Write-Fail "Could not create directory: $_"
    Read-Host "Press Enter to exit"
    exit 1
}

# ────────────────────────────────────────────────────────────────
# STEP 2 — Download all toolkit files from GitHub
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Rule
Write-Step "Downloading toolkit  ($($FILES.Count) files from GitHub)…"
Write-Rule
Write-Host ""

$dlOk   = 0
$dlFail = 0

foreach ($file in $FILES) {
    $url  = "$RAW_BASE/$file"
    $dest = "$INSTALL_DIR\$file"

    Write-Host ("    {0,-35}" -f $file) -NoNewline -ForegroundColor DarkGray
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        Write-Host " downloaded" -ForegroundColor Green
        $dlOk++
    } catch {
        Write-Host " FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $dlFail++
    }
}

Write-Host ""
if ($dlFail -gt 0) {
    Write-Fail "$dlFail file(s) could not be downloaded."
    Write-Info "Check your internet connection or visit: https://github.com/$REPO_OWNER/$REPO_NAME"
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Ok "All $dlOk files downloaded successfully."

# ────────────────────────────────────────────────────────────────
# STEP 3 — Unlock PowerShell execution policy
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Setting PowerShell execution policy to Bypass (LocalMachine)…"
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force -ErrorAction Stop
    Write-Ok "Execution policy set."
} catch {
    Write-Info "Could not set execution policy: $_ (non-fatal)"
}

# ────────────────────────────────────────────────────────────────
# STEP 4 — Launch setup.bat
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Rule
Write-Step "Launching setup.bat…"
Write-Rule
Write-Host ""
Write-Info "All output will appear in this window."
Write-Info "Logs are saved to : $INSTALL_DIR\logs\"
Write-Host ""

$setupBat = "$INSTALL_DIR\setup.bat"

if (-not (Test-Path $setupBat)) {
    Write-Fail "setup.bat not found at: $setupBat"
    Read-Host "Press Enter to exit"
    exit 1
}

# Run setup.bat in the SAME console window so the interactive menu
# (profile selection, Y/N prompts) is clearly visible and typeable.
$proc = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList "/c `"$setupBat`"" `
    -WorkingDirectory $INSTALL_DIR `
    -NoNewWindow `
    -Wait `
    -PassThru

# ────────────────────────────────────────────────────────────────
# STEP 5 — Final summary
# ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Rule

if ($proc.ExitCode -eq 0) {
    Write-Ok "Setup completed successfully."
} else {
    Write-Host ("  {0}" -f "Setup finished with warnings (exit: $($proc.ExitCode)).") -ForegroundColor Yellow
    Write-Info "Review logs at: $INSTALL_DIR\logs\"
}

Write-Host ""
Write-Info "Install location : $INSTALL_DIR"
Write-Info "Re-run any time  : irm $RAW_BASE/bootstrap.ps1 | iex"
Write-Host ""
Write-Rule
Write-Host ""

Read-Host "Press Enter to close"
