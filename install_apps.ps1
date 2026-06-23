#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs a curated, profile-aware list of applications using WinGet.
.DESCRIPTION
    Six usage profiles are supported, each installing a different app set:
      Normal       — everyday home / browsing PC
      Productivity — office, communication, document work
      Developer    — coding, version control, local dev environment
      Gaming       — gaming platforms and streaming/communication
      Creative     — media editing, recording, design
      Full         — union of every app across all profiles

    Checks whether each app is already installed before attempting installation.
    Continues past individual failures so the full list is always attempted.
    Safe to run multiple times.
.PARAMETER Profile
    Normal | Productivity | Developer | Gaming | Creative | Full
    Defaults to 'Normal' if omitted (e.g. when run standalone without setup.bat).
.NOTES
    Exit codes: 0 = all OK, 1 = one or more installs failed
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Normal', 'Productivity', 'Developer', 'Gaming', 'Creative', 'Full')]
    [string]$Profile = 'Normal'
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
$LogDir  = Join-Path $PSScriptRoot 'logs'
$LogFile = Join-Path $LogDir 'install_apps.log'
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

function Write-Section {
    param([string]$Title)
    $sep = '=' * 60
    Write-Log $sep
    Write-Log "  $Title"
    Write-Log $sep
}

# ----------------------------------------------------------------
# Master application catalogue
# Each app lists every profile it belongs to. "Full" is intentionally
# left out of each entry's tag list and instead resolved automatically
# as the union of all profiles below — so Full never goes stale when
# a new app is added to any other profile.
# ----------------------------------------------------------------
$AppCatalog = @(
    # ── Everyday / Normal ──────────────────────────────────────
    [pscustomobject]@{ Id = 'Google.Chrome';              Name = 'Google Chrome';     Profiles = @('Normal','Productivity','Developer','Gaming','Creative') }
    [pscustomobject]@{ Id = 'Mozilla.Firefox';             Name = 'Mozilla Firefox';   Profiles = @('Normal','Productivity') }
    [pscustomobject]@{ Id = 'VideoLAN.VLC';                Name = 'VLC Media Player';  Profiles = @('Normal','Creative') }
    [pscustomobject]@{ Id = '7zip.7zip';                   Name = '7-Zip';             Profiles = @('Normal','Productivity','Developer','Gaming','Creative') }
    [pscustomobject]@{ Id = 'Notepad++.Notepad++';         Name = 'Notepad++';         Profiles = @('Normal','Productivity','Developer') }
    [pscustomobject]@{ Id = 'Spotify.Spotify';             Name = 'Spotify';           Profiles = @('Normal','Creative') }
    [pscustomobject]@{ Id = 'Valve.Steam';                 Name = 'Steam';             Profiles = @('Normal','Gaming') }

    # ── Productivity ────────────────────────────────────────────
    [pscustomobject]@{ Id = 'TheDocumentFoundation.LibreOffice'; Name = 'LibreOffice';        Profiles = @('Productivity') }
    [pscustomobject]@{ Id = 'Zoom.Zoom';                   Name = 'Zoom';              Profiles = @('Productivity') }
    [pscustomobject]@{ Id = 'SlackTechnologies.Slack';     Name = 'Slack';             Profiles = @('Productivity') }
    [pscustomobject]@{ Id = 'Mozilla.Thunderbird';         Name = 'Mozilla Thunderbird'; Profiles = @('Productivity') }
    [pscustomobject]@{ Id = 'SumatraPDF.SumatraPDF';       Name = 'Sumatra PDF';       Profiles = @('Productivity') }
    [pscustomobject]@{ Id = 'ShareX.ShareX';               Name = 'ShareX';            Profiles = @('Productivity') }
    [pscustomobject]@{ Id = 'Notion.Notion';                Name = 'Notion';            Profiles = @('Productivity') }
    [pscustomobject]@{ Id = 'Microsoft.WindowsTerminal';   Name = 'Windows Terminal';  Profiles = @('Productivity','Developer') }

    # ── Developer ────────────────────────────────────────────────
    [pscustomobject]@{ Id = 'Microsoft.VisualStudioCode';  Name = 'Visual Studio Code'; Profiles = @('Developer') }
    [pscustomobject]@{ Id = 'Git.Git';                     Name = 'Git';               Profiles = @('Developer') }
    [pscustomobject]@{ Id = 'OpenJS.NodeJS.LTS';           Name = 'Node.js LTS';       Profiles = @('Developer') }
    [pscustomobject]@{ Id = 'Python.Python.3';             Name = 'Python 3';          Profiles = @('Developer') }
    [pscustomobject]@{ Id = 'Gyan.FFmpeg';                 Name = 'FFmpeg';            Profiles = @('Developer','Creative') }
    [pscustomobject]@{ Id = 'Docker.DockerDesktop';        Name = 'Docker Desktop';    Profiles = @('Developer') }
    [pscustomobject]@{ Id = 'GitHub.GitHubDesktop';        Name = 'GitHub Desktop';    Profiles = @('Developer') }
    [pscustomobject]@{ Id = 'Postman.Postman';             Name = 'Postman';           Profiles = @('Developer') }

    # ── Gaming ───────────────────────────────────────────────────
    [pscustomobject]@{ Id = 'Discord.Discord';             Name = 'Discord';           Profiles = @('Gaming') }
    [pscustomobject]@{ Id = 'OBSProject.OBSStudio';        Name = 'OBS Studio';        Profiles = @('Gaming','Creative') }
    [pscustomobject]@{ Id = 'qBittorrent.qBittorrent';     Name = 'qBittorrent';       Profiles = @('Gaming') }

    # ── Creative ─────────────────────────────────────────────────
    [pscustomobject]@{ Id = 'GIMP.GIMP';                   Name = 'GIMP';              Profiles = @('Creative') }
    [pscustomobject]@{ Id = 'Inkscape.Inkscape';           Name = 'Inkscape';          Profiles = @('Creative') }
    [pscustomobject]@{ Id = 'Audacity.Audacity';           Name = 'Audacity';          Profiles = @('Creative') }
    [pscustomobject]@{ Id = 'KDE.Krita';                   Name = 'Krita';             Profiles = @('Creative') }
    [pscustomobject]@{ Id = 'HandBrake.HandBrake';         Name = 'HandBrake';         Profiles = @('Creative') }
)

# ----------------------------------------------------------------
# Resolve which apps belong to the requested profile.
# 'Full' = union of every app in the catalogue (always in sync,
# never needs separate maintenance).
# ----------------------------------------------------------------
if ($Profile -eq 'Full') {
    $Apps = $AppCatalog
} else {
    $Apps = $AppCatalog | Where-Object { $_.Profiles -contains $Profile }
}

if (-not $Apps -or $Apps.Count -eq 0) {
    Write-Log "No applications matched profile '$Profile'. Nothing to install." 'WARN'
    exit 0
}

# ----------------------------------------------------------------
# WinGet availability
# ----------------------------------------------------------------
Write-Section "Application Installer — Profile: $Profile  ($($Apps.Count) apps)"

$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Write-Log 'WinGet binary not found in PATH. Attempting to locate App Installer…' 'WARN'

    $appInstaller = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue
    if ($appInstaller) {
        try {
            Add-AppxPackage -RegisterByFamilyName `
                -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' `
                -ErrorAction Stop
            Write-Log 'App Installer registered. Refreshing PATH…'
            $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                        [System.Environment]::GetEnvironmentVariable('Path','User')
        } catch {
            Write-Log "Could not register App Installer: $_" 'ERROR'
        }
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Log 'WinGet is not available. Install "App Installer" from the Microsoft Store and re-run.' 'ERROR'
        Write-Log 'https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1' 'ERROR'
        exit 1
    }
}

Write-Log "WinGet found : $($winget.Source)"
Write-Log 'Refreshing WinGet sources…'
winget source update --disable-interactivity 2>&1 | Out-Null

# ----------------------------------------------------------------
# Install loop
# ----------------------------------------------------------------
Write-Section "Installing $($Apps.Count) application(s) for profile '$Profile'"
foreach ($a in $Apps) { Write-Log "  Queued : $($a.Name)  [$($a.Id)]" }
Write-Log ('-' * 60)

$ok   = 0
$skip = 0
$fail = 0

# WinGet exit code: already installed
$ALREADY_INSTALLED = -1978335189   # 0x8A150054

foreach ($app in $Apps) {
    Write-Log "──────────────────────────────────────────────────────"
    Write-Log "App  : $($app.Name)"
    Write-Log "ID   : $($app.Id)"

    # ----- check if already installed -----
    $listOut = winget list --id $app.Id --exact --accept-source-agreements 2>&1
    $alreadyInstalled = ($LASTEXITCODE -eq 0) -and ($listOut -match [regex]::Escape($app.Id))

    if ($alreadyInstalled) {
        Write-Log "Status : SKIPPED (already installed)" 'INFO'
        $skip++
        continue
    }

    # ----- install -----
    Write-Log "Status : Installing…"
    $installOut = winget install `
        --id    $app.Id  `
        --exact          `
        --silent         `
        --accept-package-agreements `
        --accept-source-agreements  `
        --disable-interactivity     `
        2>&1

    $ec = $LASTEXITCODE

    if ($ec -eq 0 -or $ec -eq $ALREADY_INSTALLED) {
        Write-Log "Status : OK (exit $ec)" 'INFO'
        $ok++
    } else {
        Write-Log "Status : FAILED (exit $ec)" 'WARN'
        Write-Log "Output : $installOut" 'WARN'
        $fail++
    }
}

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------
Write-Section 'Installation Summary'
Write-Log "Profile   : $Profile"
Write-Log "Installed : $ok"
Write-Log "Skipped   : $skip  (already present)"
Write-Log "Failed    : $fail"

if ($fail -gt 0) {
    Write-Log "One or more apps failed to install. Check $LogFile for details." 'WARN'
    exit 1
}
exit 0
