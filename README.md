<div align="center">

# 🪟 Windows 11 Setup Toolkit

**One command. Pick a profile. Done.**

[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Windows 11](https://img.shields.io/badge/Windows-11-0078D4?logo=windows)](https://www.microsoft.com/windows/windows-11)
[![Idempotent](https://img.shields.io/badge/Safe%20to%20re--run-yes-brightgreen)](#idempotency)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## ⚡ One-Liner Install

Open **any** PowerShell window (elevation is handled automatically):

```powershell
irm https://raw.githubusercontent.com/YOUR_USERNAME/win11-setup/main/bootstrap.ps1 | iex
```

> Replace `YOUR_USERNAME` with your GitHub username and `win11-setup` with your repo name if different.

The bootstrap script will:
1. Request UAC elevation if needed
2. Download all toolkit files to `%LOCALAPPDATA%\Win11SetupToolkit\`
3. Launch `setup.bat`, which shows an **interactive main menu**
4. Apply the apps and settings for whichever profile you pick
5. Prompt for a reboot only if one is actually required

---

## 🎛️ Main Menu — Pick How You Use This PC

`setup.bat` opens with a menu instead of blindly installing everything. Every user
works differently, so the toolkit asks first:

```
 +----------------------------------------------------------+
 |         Windows 11 Setup Toolkit  v2.0                  |
 |         Tailored profiles for every type of user        |
 +----------------------------------------------------------+

  How will you mainly use this PC?

  +----------------------------------------------------------+
  |  1 |  Normal / Home    Browser, VLC, Spotify, Steam     |
  |  2 |  Productivity     Zoom, Slack, Office, email       |
  |  3 |  Developer        VS Code, Git, Node, Python, WSL  |
  |  4 |  Gaming           Steam, Discord, OBS, game tweaks |
  |  5 |  Creative         GIMP, Krita, Audacity, OBS       |
  |  6 |  Full Install     All apps and all settings        |
  |  7 |  Custom           Pick individual steps yourself   |
  +----------------------------------------------------------+
  |  0 |  Exit                                              |
  +----------------------------------------------------------+
```

Selecting a number shows exactly what that profile installs and changes, then asks
for a final Y/N confirmation before touching anything.

### Why this matters

A gamer doesn't need Docker Desktop. A developer doesn't need Steam. An office
laptop on battery doesn't need Ultimate Performance burning extra watts. Each
profile installs a **different, deliberately scoped app set** and applies
**genuinely different performance tuning** — not just cosmetic labels:

| Profile | Apps | Power Plan | Extra |
|---|---|---|---|
| **Normal** | 7 everyday apps | High Performance | — |
| **Productivity** | 12 office/comms apps | High Performance | — |
| **Developer** | 12 dev-stack apps | **Ultimate** Performance + HAGS | Git/npm/pip/VS Code config, WSL2, Hyper-V, Sandbox, .NET 3.5 |
| **Gaming** | 6 gaming/streaming apps | **Ultimate** Performance + HAGS | Game Mode on, Game DVR off, max GPU/CPU priority |
| **Creative** | 11 media/design apps | **Ultimate** Performance + HAGS | Low-latency multimedia tuning (helps audio/video work) |
| **Full** | All 31 apps (union, no duplicates) | **Ultimate** Performance + HAGS | Everything from every profile above |

Bloatware removal, dark mode, File Explorer cleanup, taskbar cleanup, privacy
hardening (telemetry/ads/Cortana off), and registry tweaks are universally
beneficial regardless of how you use your PC, so **every profile gets those** —
only the app list and the performance tier genuinely differ.

### Option 7 — Custom

Don't want a preset? Custom lets you:
1. Pick which app list to install from (any of the 6 profiles above)
2. Answer **Y/N** for each of the 9 setup steps individually (bloatware, apps,
   dark mode, Explorer, taskbar, performance, privacy, developer tools, Windows
   features, registry) — skip whatever you don't want

---

## 📦 Full App Catalogue

All apps install silently via **WinGet**; already-installed apps are skipped automatically.

| App | WinGet ID | Profiles |
|---|---|---|
| Google Chrome | `Google.Chrome` | Normal, Productivity, Developer, Gaming, Creative |
| Mozilla Firefox | `Mozilla.Firefox` | Normal, Productivity |
| VLC Media Player | `VideoLAN.VLC` | Normal, Creative |
| 7-Zip | `7zip.7zip` | Normal, Productivity, Developer, Gaming, Creative |
| Notepad++ | `Notepad++.Notepad++` | Normal, Productivity, Developer |
| Spotify | `Spotify.Spotify` | Normal, Creative |
| Steam | `Valve.Steam` | Normal, Gaming |
| LibreOffice | `TheDocumentFoundation.LibreOffice` | Productivity |
| Zoom | `Zoom.Zoom` | Productivity |
| Slack | `SlackTechnologies.Slack` | Productivity |
| Mozilla Thunderbird | `Mozilla.Thunderbird` | Productivity |
| Sumatra PDF | `SumatraPDF.SumatraPDF` | Productivity |
| ShareX | `ShareX.ShareX` | Productivity |
| Notion | `Notion.Notion` | Productivity |
| Windows Terminal | `Microsoft.WindowsTerminal` | Productivity, Developer |
| Visual Studio Code | `Microsoft.VisualStudioCode` | Developer |
| Git | `Git.Git` | Developer |
| Node.js LTS | `OpenJS.NodeJS.LTS` | Developer |
| Python 3 | `Python.Python.3` | Developer |
| FFmpeg | `Gyan.FFmpeg` | Developer, Creative |
| Docker Desktop | `Docker.DockerDesktop` | Developer |
| GitHub Desktop | `GitHub.GitHubDesktop` | Developer |
| Postman | `Postman.Postman` | Developer |
| Discord | `Discord.Discord` | Gaming |
| OBS Studio | `OBSProject.OBSStudio` | Gaming, Creative |
| qBittorrent | `qBittorrent.qBittorrent` | Gaming |
| GIMP | `GIMP.GIMP` | Creative |
| Inkscape | `Inkscape.Inkscape` | Creative |
| Audacity | `Audacity.Audacity` | Creative |
| Krita | `KDE.Krita` | Creative |
| HandBrake | `HandBrake.HandBrake` | Creative |

`Full` installs all 31 rows above — it's the literal union, so it never needs separate maintenance.

---

## 🗑️ Bloatware Removed (every profile)

| Removed | Provisioned package also purged |
|---|---|
| Xbox App + overlays | ✅ |
| Clipchamp | ✅ |
| Microsoft Teams (consumer) | ✅ |
| Bing News & Weather | ✅ |
| Windows Maps | ✅ |
| People & Skype | ✅ |
| Mixed Reality Portal | ✅ |
| Solitaire Collection | ✅ |
| Office Hub, OneNote Store | ✅ |
| Phone Link, Power Automate | ✅ |
| Feedback Hub, Tips | ✅ |
| Movies & TV, Groove Music | ✅ |

> **Not removed:** Store, Edge, Settings, Defender — system components Windows requires.

---

## 🔧 What Gets Configured

<details>
<summary><b>🌑 Dark Mode (universal)</b></summary>

- System shell + all apps use dark theme
- Machine-level default (new accounts inherit it)
- Transparency on, Aero Peek off
- Broadcast to running apps — no sign-out needed

</details>

<details>
<summary><b>📁 File Explorer (universal)</b></summary>

| Setting | Value |
|---|---|
| Show file extensions | ✅ On |
| Show hidden files | ✅ On |
| Show OS/system files | ✅ On |
| Full path in title + address bar | ✅ On |
| Open to | **This PC** |
| Recent files / Frequent folders | ❌ Off |
| Sync provider notifications | ❌ Off |
| Status bar | ✅ On |
| Compact view | ❌ Off |

</details>

<details>
<summary><b>📌 Taskbar (universal)</b></summary>

| Item | State |
|---|---|
| Widgets | 🙈 Hidden |
| Search | 🙈 Hidden |
| Copilot | 🙈 Hidden |
| Chat (Teams) | 🙈 Hidden |
| Task View | 🙈 Hidden |
| Alignment | ⬅ Left |

</details>

<details>
<summary><b>⚡ Performance (varies by profile — see table above)</b></summary>

**Universal, every profile:**
- Power plan: High Performance (minimum) — Ultimate on max-perf profiles
- Sleep on AC: never — monitor timeout 15 min
- Hibernation disabled (reclaims `hiberfil.sys`, often 8–32 GB)
- Visual effects tuned to a balanced custom set
- Memory management: kernel stays in RAM, prefetch enabled
- Foreground process priority boost (3:1 quanta)
- NTFS: last-access timestamps off, 8.3 names off
- Startup delay: 0 ms
- SSD detected → Storage Optimizer (TRIM) verified enabled

**Developer / Gaming / Creative / Full only:**
- **Ultimate Performance** power plan (falls back to High Performance if unavailable on the SKU)
- Hardware Accelerated GPU Scheduling (HAGS)
- Multimedia profile tuned for low latency (`SystemResponsiveness=0`, network throttling disabled, foreground task GPU/CPU priority boost)
- Game Mode auto-enabled, Game DVR/Game Bar capture disabled

> Windows Update and Defender are **never** touched, in any profile.

</details>

<details>
<summary><b>🔒 Privacy (universal)</b></summary>

| What | Action |
|---|---|
| Telemetry | Policy → 0 (Security/Off) |
| DiagTrack service | Stopped + disabled |
| Advertising ID | Disabled |
| Content delivery / suggested apps | All ~35 subscriptions off |
| Cortana + Bing in Start | Disabled |
| Activity History / Timeline | Disabled |
| Windows Error Reporting | Disabled |
| Lock-screen spotlight / ads | Disabled |
| Feedback request frequency | 0 |
| Tailored experiences | Disabled |

</details>

<details>
<summary><b>🛠️ Developer Tools (Developer + Full profiles only)</b></summary>

**Git** — system-level config: long paths, `init.defaultBranch = main`,
`autocrlf = true`, Git Credential Manager, `diff.algorithm = histogram`,
aliases (`st`, `co`, `br`, `ci`, `df`, `lg`, `unstage`, `last`).

**Node.js / npm** — global prefix → `%LOCALAPPDATA%\npm` (no UAC for global
installs), npm updated to latest, added to Machine PATH.

**Python** — pip upgraded; `virtualenv pipenv wheel setuptools black pylint` installed.

**VS Code** — extensions (GitLens, Pylance, ESLint, Prettier, Remote-WSL,
Docker, Material Theme) + `settings.json` (merged, never overwritten): format
on save, telemetry off, auto-save, Git autofetch.

**System** — Developer Mode enabled, Long Path support enabled (> 260 chars).

</details>

<details>
<summary><b>🪟 Optional Windows Features (Developer + Full profiles only)</b></summary>

| Feature | Requirement |
|---|---|
| .NET Framework 3.5 | Any edition |
| Telnet Client | Any edition |
| Hyper-V | Pro/Enterprise + VT-x/AMD-V in BIOS |
| Windows Sandbox | Pro/Enterprise + VT-x/AMD-V in BIOS |
| WSL2 | Any edition + VT-x/AMD-V in BIOS |

WSL2 registers a one-shot post-reboot helper to run `wsl --set-default-version 2`
automatically.

</details>

---

## 📂 Repository Structure

```
win11-setup/
├── bootstrap.ps1           ← irm entry point
├── setup.bat               ← interactive menu + orchestrator
├── install_apps.ps1        ← profile-aware WinGet installer
├── remove_bloatware.ps1
├── dark_mode.ps1
├── explorer_settings.ps1
├── taskbar_settings.ps1
├── performance_tweaks.ps1  ← profile-aware power plan + tuning
├── privacy_tweaks.ps1
├── developer_tools.ps1
├── windows_features.ps1
├── registry_tweaks.reg
├── .gitignore
└── README.md
```

After running, the toolkit lives at `%LOCALAPPDATA%\Win11SetupToolkit\` with
per-script logs in `logs\`.

---

## 🔁 Re-running & Updating

Re-run the same one-liner any time — it always pulls the latest files from GitHub
and shows the menu again, so you can pick a different profile or top up a machine:

```powershell
irm https://raw.githubusercontent.com/YOUR_USERNAME/win11-setup/main/bootstrap.ps1 | iex
```

Every script is **idempotent**:
- Installed apps → skipped
- Removed apps → skipped if already gone
- Registry values → overwritten with same value (no side effects)
- Windows features → skipped if already enabled

Running a second profile on the same machine is safe — it layers on top
(e.g. run **Developer** first, then **Gaming** later to add gaming apps without
undoing your dev setup; only the power plan will switch to whichever profile ran
most recently).

---

## 🛠️ Customisation

### Add an app to a profile
Edit `install_apps.ps1`, add a row to `$AppCatalog` with the profiles it should belong to:
```powershell
[pscustomobject]@{ Id = 'Publisher.AppName'; Name = 'Display Name'; Profiles = @('Developer','Full') }
```
`Full` is automatically the union of everything — you never need to add an app to `Full` by hand.
Find IDs: `winget search "app name"` or [winget.run](https://winget.run)

### Remove a bloatware app
Edit `remove_bloatware.ps1`, add to `$Bloatware`:
```powershell
'Microsoft.PackageName'
```
Find names: `Get-AppxPackage | Select-Object Name | Sort-Object Name`

### Add a new profile
1. In `install_apps.ps1`, add the new profile name to the `ValidateSet` and tag relevant apps with it in `$AppCatalog`
2. In `performance_tweaks.ps1`, add it to `$MaxPerfProfiles` if it should get Ultimate Performance + HAGS
3. In `setup.bat`, add a new `INFO_*` screen (copy an existing one) and a menu entry in `:MAINMENU`

### Run a single script directly
```powershell
# Elevated PowerShell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install_apps.ps1 -Profile Developer
.\performance_tweaks.ps1 -Profile Gaming
```

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| `WinGet not found` | Install [App Installer](https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1) from the Microsoft Store |
| App fails to install | Re-run — WinGet is retried. Check `logs\install_apps.log` |
| Hyper-V unavailable | Requires Windows **Pro/Enterprise** + VT-x/AMD-V enabled in BIOS/UEFI |
| WSL2 not working after reboot | Run: `wsl --set-default-version 2` then `wsl --install -d Ubuntu` |
| Taskbar still shows Copilot | Sign out and back in — policy changes need a full shell restart |
| `Access denied` on a registry key | Non-fatal — logged as WARN and skipped |
| Menu doesn't appear / window closes instantly | Make sure you're running via the `irm \| iex` one-liner or `setup.bat` directly — don't double-click a `.ps1` file in Explorer |

---

## ⚠️ Security Note

Review all scripts before running. This toolkit only:
- Modifies HKCU and HKLM registry keys
- Installs apps via the official WinGet source
- Removes optional Microsoft inbox apps
- Enables/disables Windows Optional Features via DISM

It does **not** touch passwords, network adapters, BitLocker, Remote Desktop,
Windows Update, or Windows Defender.

---

## 📋 Requirements

| | |
|-|-|
| OS | Windows 11 (22H2 or later recommended) |
| Privileges | Admin (UAC prompt is automatic) |
| Internet | Required for the app-download step only |
| WinGet | Included with Windows 11 via App Installer |
| PowerShell | 5.1+ (inbox on all Windows 11 installs) |
| Local accounts | ✅ Fully supported — no Microsoft account needed |

---

## 📄 License

MIT — free for personal and organisational use. No warranty expressed or implied.
