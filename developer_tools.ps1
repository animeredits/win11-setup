#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configures developer tools after WinGet installation.
.DESCRIPTION
    Git   — long paths, default branch main, LF line endings, GCM, aliases
    npm   — cache path, global prefix, update npm itself
    pip   — upgrade pip, install virtualenv / pipenv / wheel
    VS Code — installs useful extensions and writes settings.json
    Windows — enables Developer Mode and Long Path support (260+ chars)
    Safe to run multiple times (idempotent).
#>

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
$LogDir  = Join-Path $PSScriptRoot 'logs'
$LogFile = Join-Path $LogDir 'developer_tools.log'
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
    } catch { Write-Log "  WARN $Name : $_" 'WARN' }
}

# Refresh PATH so newly installed tools are visible
function Update-EnvPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path','User')
}

Update-EnvPath

Write-Log ('=' * 60)
Write-Log 'Developer Tools Configuration'
Write-Log ('=' * 60)

# ================================================================
# 1. Git
# ================================================================
Write-Log '--- Git ---'

$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    Write-Log "  Found: $(git --version 2>&1)"

    # System-level settings (apply to all users)
    $gitCfg = @{
        # Core
        'core.longpaths'          = 'true'
        'core.autocrlf'           = 'true'     # Windows: commit LF, checkout CRLF
        'core.fscache'            = 'true'
        'core.preloadindex'       = 'true'
        'core.symlinks'           = 'false'

        # Defaults
        'init.defaultBranch'      = 'main'

        # Credential manager
        'credential.helper'       = 'manager'

        # Safe directories
        'safe.directory'          = '*'

        # Push behaviour
        'push.default'            = 'simple'
        'push.autoSetupRemote'    = 'true'

        # Pull behaviour
        'pull.rebase'             = 'false'

        # Performance
        'gc.auto'                 = '256'
        'pack.threads'            = '0'        # auto-detect CPU count

        # Diff / merge
        'diff.algorithm'          = 'histogram'
        'merge.conflictstyle'     = 'diff3'

        # Aliases
        'alias.st'                = 'status -sb'
        'alias.co'                = 'checkout'
        'alias.br'                = 'branch'
        'alias.ci'                = 'commit'
        'alias.df'                = 'diff'
        'alias.lg'                = 'log --oneline --graph --all --decorate'
        'alias.unstage'           = 'reset HEAD --'
        'alias.last'              = 'log -1 HEAD --stat'
        'alias.aliases'           = 'config --list --show-scope'
        'alias.ignored'           = 'ls-files --others --ignored --exclude-standard'
    }

    foreach ($kv in $gitCfg.GetEnumerator()) {
        $out = git config --system $kv.Key $kv.Value 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "  git config --system $($kv.Key) = $($kv.Value)"
        } else {
            Write-Log "  WARN git config $($kv.Key): $out" 'WARN'
        }
    }
    Write-Log '  Git configured.'
} else {
    Write-Log '  Git not found in PATH. Install via install_apps.ps1 first.' 'WARN'
}

# ================================================================
# 2. Node.js / npm
# ================================================================
Write-Log '--- Node.js / npm ---'

Update-EnvPath
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    Write-Log "  Node : $(node --version 2>&1)"
    Write-Log "  npm  : $(npm --version 2>&1)"

    # npm global prefix and cache under LOCALAPPDATA (no UAC needed)
    $npmPrefix = "$env:LOCALAPPDATA\npm"
    $npmCache  = "$env:LOCALAPPDATA\npm-cache"

    foreach ($d in $npmPrefix, $npmCache) {
        if (-not (Test-Path $d)) { New-Item -Path $d -ItemType Directory -Force | Out-Null }
    }

    npm config set prefix       $npmPrefix 2>&1 | Out-Null
    npm config set cache        $npmCache  2>&1 | Out-Null
    npm config set update-notifier false   2>&1 | Out-Null
    npm config set fund         false      2>&1 | Out-Null
    npm config set loglevel     warn       2>&1 | Out-Null
    Write-Log "  npm prefix : $npmPrefix"
    Write-Log "  npm cache  : $npmCache"

    # Add npm global prefix to Machine PATH if absent
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path','Machine')
    if ($machinePath -notlike "*$npmPrefix*") {
        [System.Environment]::SetEnvironmentVariable(
            'Path', "$machinePath;$npmPrefix", 'Machine')
        Write-Log "  Added $npmPrefix to Machine PATH."
        Update-EnvPath
    }

    # Update npm itself
    Write-Log '  Updating npm…'
    $npmOut = npm install -g npm@latest 2>&1
    Write-Log "  npm update : $($npmOut | Select-Object -Last 1)"

    Write-Log '  Node.js / npm configured.'
} else {
    Write-Log '  Node.js not found. Install via install_apps.ps1 first.' 'WARN'
}

# ================================================================
# 3. Python / pip
# ================================================================
Write-Log '--- Python / pip ---'

Update-EnvPath
$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    Write-Log "  Python : $(python --version 2>&1)"

    # Upgrade pip
    Write-Log '  Upgrading pip…'
    python -m pip install --upgrade pip --quiet 2>&1 | Out-Null
    Write-Log "  pip : $(pip --version 2>&1)"

    # Useful packages every dev wants
    $pipPkgs = @('virtualenv', 'pipenv', 'wheel', 'setuptools', 'black', 'pylint')
    foreach ($pkg in $pipPkgs) {
        Write-Log "  pip install $pkg…"
        pip install $pkg --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "    OK : $pkg"
        } else {
            Write-Log "    WARN : $pkg failed" 'WARN'
        }
    }

    # pip: no progress bar in scripts
    python -m pip config set global.progress_bar off 2>&1 | Out-Null

    Write-Log '  Python configured.'
} else {
    Write-Log '  Python not found. Install via install_apps.ps1 first.' 'WARN'
}

# ================================================================
# 4. VS Code
# ================================================================
Write-Log '--- VS Code ---'

Update-EnvPath
$code = Get-Command code -ErrorAction SilentlyContinue

# Fallback — look in standard install paths
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
    Write-Log "  VS Code found: $codeCmd"

    # Extensions to install
    $extensions = @(
        # Language support
        'ms-python.python'
        'ms-python.vscode-pylance'
        'ms-vscode.powershell'
        'dbaeumer.vscode-eslint'
        'esbenp.prettier-vscode'
        'ms-vscode.cpptools'

        # Git
        'eamodio.gitlens'
        'mhutchie.git-graph'

        # Productivity
        'christian-kohler.path-intellisense'
        'formulahendry.auto-close-tag'
        'formulahendry.auto-rename-tag'
        'streetsidesoftware.code-spell-checker'
        'ms-vscode.live-server'
        'humao.rest-client'

        # Remote / containers
        'ms-vscode-remote.remote-wsl'
        'ms-vscode-remote.remote-containers'
        'ms-azuretools.vscode-docker'

        # Theme / icons
        'PKief.material-icon-theme'
        'zhuangtongfa.material-theme'
    )

    foreach ($ext in $extensions) {
        Write-Log "  Installing extension: $ext…"
        $out = & $codeCmd --install-extension $ext --force 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "    OK : $ext"
        } else {
            Write-Log "    WARN : $ext — $out" 'WARN'
        }
    }

    # Settings.json
    $settingsDir = "$env:APPDATA\Code\User"
    if (-not (Test-Path $settingsDir)) { New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null }
    $settingsFile = "$settingsDir\settings.json"

    $newSettings = [ordered]@{
        # Editor
        'editor.fontSize'                        = 14
        'editor.tabSize'                         = 2
        'editor.wordWrap'                        = 'on'
        'editor.formatOnSave'                    = $true
        'editor.renderWhitespace'                = 'boundary'
        'editor.minimap.enabled'                 = $false
        'editor.bracketPairColorization.enabled' = $true
        'editor.guides.bracketPairs'             = 'active'
        'editor.linkedEditing'                   = $true
        'editor.stickyScroll.enabled'            = $true
        'editor.suggestSelection'                = 'first'
        'editor.cursorBlinking'                  = 'smooth'
        'editor.smoothScrolling'                 = $true

        # Workbench
        'workbench.colorTheme'                   = 'Material Theme Darker High Contrast'
        'workbench.iconTheme'                    = 'material-icon-theme'
        'workbench.startupEditor'                = 'none'
        'workbench.editor.tabCloseButton'        = 'right'
        'workbench.tree.indent'                  = 16
        'workbench.editor.highlightModifiedTabs' = $true

        # Terminal
        'terminal.integrated.fontSize'           = 13
        'terminal.integrated.defaultProfile.windows' = 'PowerShell'
        'terminal.integrated.cursorBlinking'     = $true

        # Files
        'files.autoSave'                         = 'onFocusChange'
        'files.eol'                              = "`n"
        'files.trimTrailingWhitespace'           = $true
        'files.insertFinalNewline'               = $true

        # Explorer
        'explorer.confirmDelete'                 = $false
        'explorer.confirmDragAndDrop'            = $false
        'explorer.compactFolders'                = $false

        # Git
        'git.confirmSync'                        = $false
        'git.autofetch'                          = $true
        'git.enableSmartCommit'                  = $true
        'git.autofetchPeriod'                    = 180
        'git.decorations.enabled'                = $true

        # Privacy — disable all telemetry
        'telemetry.telemetryLevel'               = 'off'
        'extensions.autoCheckUpdates'            = $false
        'update.mode'                            = 'manual'

        # Breadcrumbs
        'breadcrumbs.enabled'                    = $true

        # Prettier
        '[javascript]'                           = @{ 'editor.defaultFormatter' = 'esbenp.prettier-vscode' }
        '[typescript]'                           = @{ 'editor.defaultFormatter' = 'esbenp.prettier-vscode' }
        '[json]'                                 = @{ 'editor.defaultFormatter' = 'esbenp.prettier-vscode' }
        '[html]'                                 = @{ 'editor.defaultFormatter' = 'esbenp.prettier-vscode' }
        '[css]'                                  = @{ 'editor.defaultFormatter' = 'esbenp.prettier-vscode' }
        '[python]'                               = @{ 'editor.defaultFormatter' = 'ms-python.black-formatter' }
    }

    # Merge with existing settings if present
    if (Test-Path $settingsFile) {
        Write-Log '  Merging with existing settings.json…'
        try {
            $existing = Get-Content $settingsFile -Raw | ConvertFrom-Json -AsHashtable
            foreach ($k in $newSettings.Keys) { $existing[$k] = $newSettings[$k] }
            $newSettings = $existing
        } catch {
            Write-Log "  Could not parse existing settings.json — overwriting: $_" 'WARN'
        }
    }

    $newSettings | ConvertTo-Json -Depth 10 |
        Out-File -FilePath $settingsFile -Encoding UTF8 -Force
    Write-Log "  settings.json written to $settingsFile"

    Write-Log '  VS Code configured.'
} else {
    Write-Log '  VS Code not found. Install via install_apps.ps1 first.' 'WARN'
}

# ================================================================
# 5. Windows Developer Mode
# ================================================================
Write-Log '--- Windows Developer Mode ---'
$devMode = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
Set-Reg -Path $devMode -Name 'AllowDevelopmentWithoutDevLicense' -Value 1
Set-Reg -Path $devMode -Name 'AllowAllTrustedApps'               -Value 1
Write-Log '  Developer Mode enabled.'

# ================================================================
# 6. Long Path Support (enables paths > 260 chars)
# ================================================================
Write-Log '--- Long Path Support ---'
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1
Write-Log '  LongPathsEnabled = 1'

Write-Log ('=' * 60)
Write-Log 'Developer tools configuration complete.'
Write-Log ('=' * 60)
exit 0
