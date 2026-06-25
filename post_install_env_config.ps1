#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Auto-configure development environments after app installation.
.DESCRIPTION
    Runs after WinGet installs complete. Automatically sets up:
      - Git: long paths, main branch, credential manager, aliases
      - Node/npm: global prefix, PATH setup, npm update
      - Python: pip upgrade, virtualenv/pipenv/black/pylint
      - Docker: daemon auto-start, verify installation
      - Android Studio: SDK paths, environment variables
      - VS Code: extensions
    
    Idempotent — safe to run multiple times.
.PARAMETER Profile
    Developer | Full (only these profiles need env setup)
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Developer', 'Full')]
    [string]$Profile = 'Developer'
)

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ================================================================
# Logging
# ================================================================
$LogDir  = Join-Path $PSScriptRoot 'logs'
$LogFile = Join-Path $LogDir 'post_install_env_config.log'
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

function Update-EnvPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path','User')
}

Update-EnvPath

Write-Log ('=' * 60)
Write-Log "Post-Install Environment Configuration — Profile: $Profile"
Write-Log ('=' * 60)

# ================================================================
# 1. GIT CONFIGURATION
# ================================================================
Write-Log '--- Git Configuration ---'

$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    Write-Log "Git found: $(git --version 2>&1)"

    $gitConfig = @{
        'core.longpaths'          = 'true'
        'core.autocrlf'           = 'true'
        'core.fscache'            = 'true'
        'core.preloadindex'       = 'true'
        'core.symlinks'           = 'false'
        'init.defaultBranch'      = 'main'
        'credential.helper'       = 'manager'
        'safe.directory'          = '*'
        'push.default'            = 'simple'
        'push.autoSetupRemote'    = 'true'
        'pull.rebase'             = 'false'
        'gc.auto'                 = '256'
        'pack.threads'            = '0'
        'diff.algorithm'          = 'histogram'
        'merge.conflictstyle'     = 'diff3'
        'alias.st'                = 'status -sb'
        'alias.co'                = 'checkout'
        'alias.br'                = 'branch'
        'alias.ci'                = 'commit'
        'alias.df'                = 'diff'
        'alias.lg'                = 'log --oneline --graph --all --decorate'
        'alias.unstage'           = 'reset HEAD --'
        'alias.last'              = 'log -1 HEAD --stat'
    }

    foreach ($kv in $gitConfig.GetEnumerator()) {
        $out = git config --system $kv.Key $kv.Value 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "  git config --system $($kv.Key) = $($kv.Value)"
        } else {
            Write-Log "  WARN git config $($kv.Key): $out" 'WARN'
        }
    }
} else {
    Write-Log '  Git not installed — skipped' 'WARN'
}

# ================================================================
# 2. NODE.JS / NPM CONFIGURATION
# ================================================================
Write-Log '--- Node.js / npm Configuration ---'

Update-EnvPath
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    Write-Log "Node: $(node --version 2>&1)"
    Write-Log "npm:  $(npm --version 2>&1)"

    # NPM global prefix to LOCALAPPDATA (no UAC needed)
    $npmPrefix = "$env:LOCALAPPDATA\npm"
    $npmCache  = "$env:LOCALAPPDATA\npm-cache"

    foreach ($d in $npmPrefix, $npmCache) {
        if (-not (Test-Path $d)) { 
            New-Item -Path $d -ItemType Directory -Force | Out-Null
            Write-Log "  Created: $d"
        }
    }

    npm config set prefix $npmPrefix 2>&1 | Out-Null
    npm config set cache $npmCache 2>&1 | Out-Null
    npm config set update-notifier false 2>&1 | Out-Null
    npm config set fund false 2>&1 | Out-Null
    npm config set loglevel warn 2>&1 | Out-Null
    
    Write-Log "  npm prefix: $npmPrefix"
    Write-Log "  npm cache: $npmCache"

    # Add npm prefix to Machine PATH if not already there
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path','Machine')
    if ($machinePath -notlike "*$npmPrefix*") {
        [System.Environment]::SetEnvironmentVariable(
            'Path', "$machinePath;$npmPrefix", 'Machine')
        Write-Log "  Added $npmPrefix to Machine PATH"
        Update-EnvPath
    }

    # Update npm itself
    Write-Log '  Updating npm to latest…'
    $npmOut = npm install -g npm@latest 2>&1
    Write-Log "  npm updated: $($npmOut | Select-Object -Last 1)"
} else {
    Write-Log '  Node.js not installed — skipped' 'WARN'
}

# ================================================================
# 3. PYTHON / PIP CONFIGURATION
# ================================================================
Write-Log '--- Python / pip Configuration ---'

Update-EnvPath
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    Write-Log "Python: $(python --version 2>&1)"

    # Upgrade pip
    Write-Log '  Upgrading pip…'
    python -m pip install --upgrade pip --quiet 2>&1 | Out-Null
    Write-Log "  pip: $(pip --version 2>&1)"

    # Install useful dev packages
    $pipPkgs = @('virtualenv', 'pipenv', 'wheel', 'setuptools', 'black', 'pylint')
    foreach ($pkg in $pipPkgs) {
        pip install $pkg --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "    OK : $pkg"
        } else {
            Write-Log "    WARN : $pkg (failed)" 'WARN'
        }
    }

    # Disable progress bar in scripts
    python -m pip config set global.progress_bar off 2>&1 | Out-Null
    Write-Log '  Python packages installed and configured'
} else {
    Write-Log '  Python not installed — skipped' 'WARN'
}

# ================================================================
# 4. DOCKER CONFIGURATION
# ================================================================
Write-Log '--- Docker Configuration ---'

Update-EnvPath
$docker = Get-Command docker -ErrorAction SilentlyContinue
if ($docker) {
    Write-Log "Docker found: $(docker --version 2>&1)"

    # Enable Docker service on startup
    try {
        $dockerSvc = Get-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue
        if ($dockerSvc) {
            Start-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue
            Set-Service -Name 'com.docker.service' -StartupType Automatic -ErrorAction SilentlyContinue
            Write-Log '  Docker service set to Auto-start'
        } else {
            Write-Log '  Docker service not found (Docker Desktop may need manual start)' 'WARN'
        }
    } catch {
        Write-Log "  Could not configure Docker service: $_" 'WARN'
    }

    # Verify Docker daemon
    $dockerTest = docker run --rm hello-world 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log '  Docker daemon: working ✓'
    } else {
        Write-Log '  Docker daemon: not responding (may need Desktop restart)' 'WARN'
    }
} else {
    Write-Log '  Docker not installed — skipped' 'WARN'
}

# ================================================================
# 5. ANDROID STUDIO CONFIGURATION
# ================================================================
Write-Log '--- Android Studio Configuration ---'

$androidStudioPaths = @(
    "$env:ProgramFiles\Android\Android Studio"
    "$env:ProgramFiles(x86)\Android\Android Studio"
)

$androidStudioFound = $false
foreach ($path in $androidStudioPaths) {
    if (Test-Path $path) {
        $androidStudioFound = $true
        Write-Log "Android Studio found: $path"
        break
    }
}

if ($androidStudioFound) {
    # Set ANDROID_HOME
    $androidHome = "$env:LOCALAPPDATA\Android\Sdk"
    [Environment]::SetEnvironmentVariable('ANDROID_HOME', $androidHome, 'User')
    $env:ANDROID_HOME = $androidHome
    Write-Log "  ANDROID_HOME: $androidHome"

    # Ensure SDK directory exists
    if (-not (Test-Path $androidHome)) {
        New-Item -Path $androidHome -ItemType Directory -Force | Out-Null
        Write-Log "  Created SDK directory: $androidHome"
    }

    # Add Android tools to PATH
    $userPath = [System.Environment]::GetEnvironmentVariable('Path','User')
    $androidBinPath = "$androidHome\platform-tools"
    
    if ($userPath -notlike "*$androidBinPath*") {
        [System.Environment]::SetEnvironmentVariable(
            'Path', "$userPath;$androidBinPath", 'User')
        Write-Log "  Added platform-tools to User PATH"
        Update-EnvPath
    }

    Write-Log '  Android Studio configured'
} else {
    Write-Log '  Android Studio not installed — skipped' 'WARN'
}

# ================================================================
# 6. VS CODE EXTENSIONS
# ================================================================
Write-Log '--- VS Code Extensions ---'

Update-EnvPath
$code = Get-Command code -ErrorAction SilentlyContinue

if (-not $code) {
    $codePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    )
    foreach ($p in $codePaths) {
        if (Test-Path $p) { $code = @{ Source = $p }; break }
    }
}

if ($code) {
    $codeCmd = if ($code -is [System.Management.Automation.CommandInfo]) { 'code' } else { $code.Source }
    
    $extensions = @(
        'ms-python.python'
        'ms-python.vscode-pylance'
        'ms-vscode.powershell'
        'dbaeumer.vscode-eslint'
        'esbenp.prettier-vscode'
        'eamodio.gitlens'
        'mhutchie.git-graph'
        'ms-vscode-remote.remote-wsl'
        'ms-azuretools.vscode-docker'
        'ms-vscode.live-server'
        'humao.rest-client'
    )

    Write-Log "Installing $($extensions.Count) VS Code extensions…"
    foreach ($ext in $extensions) {
        & $codeCmd --install-extension $ext --force 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "  OK : $ext"
        } else {
            Write-Log "  WARN : $ext (may already be installed)" 'WARN'
        }
    }
} else {
    Write-Log '  VS Code not found — skipped' 'WARN'
}

# ================================================================
# SUMMARY
# ================================================================
Write-Log ('=' * 60)
Write-Log "Environment configuration complete — Profile: $Profile"
Write-Log ('=' * 60)

Write-Host ""
Write-Host "  Environment Configuration Complete" -ForegroundColor Green
Write-Host "  All development tools are ready to use."
Write-Host ""

exit 0
