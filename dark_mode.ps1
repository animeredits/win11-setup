#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Enables Windows 11 dark mode system-wide.
.DESCRIPTION
    Sets dark mode for both apps and the Windows shell for the current user
    and as the machine-level default (new accounts will inherit dark mode).
    Broadcasts the WM_SETTINGCHANGE message so running apps can react without
    a sign-out. Safe to run multiple times.
#>

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------
# Logging
# ----------------------------------------------------------------
$LogDir  = Join-Path $PSScriptRoot 'logs'
$LogFile = Join-Path $LogDir 'dark_mode.log'
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
        Write-Log "  SET  $Name = $Value  ($Type)"
    } catch {
        Write-Log "  WARN $Name : $_" 'WARN'
    }
}

# ----------------------------------------------------------------
# Win32 broadcast helper (inline C#)
# ----------------------------------------------------------------
$broadcastCode = @'
using System;
using System.Runtime.InteropServices;
public static class Win32Broadcast {
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr SendMessageTimeout(
        IntPtr   hWnd,
        uint     Msg,
        UIntPtr  wParam,
        string   lParam,
        uint     fuFlags,
        uint     uTimeout,
        out UIntPtr lpdwResult);

    private const uint   WM_SETTINGCHANGE     = 0x001A;
    private const uint   SMTO_ABORTIFHUNG     = 0x0002;
    private static readonly IntPtr HWND_BROADCAST = new IntPtr(0xFFFF);

    public static void BroadcastThemeChange() {
        UIntPtr res;
        SendMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE,
            UIntPtr.Zero, "ImmersiveColorSet",
            SMTO_ABORTIFHUNG, 1000, out res);
    }
}
'@

try {
    Add-Type -TypeDefinition $broadcastCode -ErrorAction Stop
} catch {
    Write-Log "Could not compile broadcast helper (non-fatal): $_" 'WARN'
}

# ----------------------------------------------------------------
# Registry paths
# ----------------------------------------------------------------
$cuPersonalize  = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$lmPersonalize  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$cuDwm          = 'HKCU:\SOFTWARE\Microsoft\Windows\DWM'

Write-Log ('=' * 60)
Write-Log 'Enabling Dark Mode'
Write-Log ('=' * 60)

# ── Current-user dark mode ────────────────────────────────────────
Write-Log '--- Current user (HKCU) ---'
Set-Reg -Path $cuPersonalize -Name 'AppsUseLightTheme'    -Value 0
Set-Reg -Path $cuPersonalize -Name 'SystemUsesLightTheme' -Value 0
Set-Reg -Path $cuPersonalize -Name 'EnableTransparency'   -Value 1

# ── Machine default (new accounts inherit dark mode) ─────────────
Write-Log '--- Machine default (HKLM) ---'
Set-Reg -Path $lmPersonalize -Name 'AppsUseLightTheme'    -Value 0
Set-Reg -Path $lmPersonalize -Name 'SystemUsesLightTheme' -Value 0

# ── DWM / accent ─────────────────────────────────────────────────
Write-Log '--- DWM accent settings ---'
Set-Reg -Path $cuDwm -Name 'ColorPrevalence'         -Value 0   # no accent on borders
Set-Reg -Path $cuDwm -Name 'EnableWindowColorization' -Value 1
Set-Reg -Path $cuDwm -Name 'EnableAeroPeek'           -Value 0  # less chrome noise

# ── Apply dark theme file (sets Start + taskbar colour) ──────────
$darkTheme = "$env:SystemRoot\Resources\Themes\dark.theme"
if (Test-Path $darkTheme) {
    Write-Log 'Dark theme file found — registry values will activate it on next Explorer restart.'
} else {
    Write-Log 'dark.theme not found (this is fine on some builds).' 'WARN'
}

# ── Broadcast change so open apps react ──────────────────────────
Write-Log 'Broadcasting ImmersiveColorSet theme-change message…'
try {
    [Win32Broadcast]::BroadcastThemeChange()
    Write-Log 'Broadcast sent.'
} catch {
    Write-Log "Broadcast skipped (type may not be loaded): $_" 'WARN'
}

# ── Restart Explorer to apply shell dark mode immediately ─────────
Write-Log 'Restarting Explorer to apply dark shell…'
try {
    $explorerProcs = Get-Process -Name 'explorer' -ErrorAction SilentlyContinue
    if ($explorerProcs) {
        Stop-Process -Name 'explorer' -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    Start-Process 'explorer.exe'
    Write-Log 'Explorer restarted.'
} catch {
    Write-Log "Could not restart Explorer: $_ (sign out to apply)" 'WARN'
}

Write-Log ('=' * 60)
Write-Log 'Dark mode enabled successfully.'
Write-Log ('=' * 60)
exit 0
