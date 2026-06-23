@echo off
setlocal enabledelayedexpansion
mode con cols=72 lines=48 >nul 2>&1

:: ================================================================
::  Windows 11 Setup Toolkit  v2.0
::  Profile-based setup — Normal, Productivity, Developer,
::  Gaming, Creative, Full Install, Hybrid, or Custom
:: ================================================================

set "TOOLKIT_DIR=%~dp0"
set "LOG_DIR=%TOOLKIT_DIR%logs"
set "PS=powershell.exe -NoProfile -ExecutionPolicy Bypass -File"
set "ERRORS=0"
set "REBOOT_REQUIRED=0"
set "PROFILE_NAME="
set "HYBRID_PROFILE="

for /f "tokens=*" %%T in (
    'powershell -NoProfile -Command "Get-Date -Format ''yyyyMMdd_HHmmss''"'
) do set "TS=%%T"
set "MASTER_LOG=%LOG_DIR%\setup_%TS%.log"

:: ----------------------------------------------------------------
:: Admin check
:: ----------------------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    cls
    echo.
    echo  +----------------------------------------------------------+
    echo  ^|  ERROR: Administrator privileges required.              ^|
    echo  ^|  Right-click setup.bat  ^>  Run as administrator        ^|
    echo  +----------------------------------------------------------+
    echo.
    pause
    exit /b 1
)

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

powershell.exe -NoProfile -Command ^
    "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force" ^
    >> "%MASTER_LOG%" 2>&1

call :LOG "================================================================"
call :LOG "Windows 11 Setup Toolkit started  [%date% %time%]"
call :LOG "================================================================"

:: ================================================================
::  STEP 0 — Gather device info (always runs first, no menu yet)
:: ================================================================
cls
echo.
echo  +----------------------------------------------------------+
echo  ^|  Windows 11 Setup Toolkit  v2.0                        ^|
echo  ^|  Gathering system information first...                  ^|
echo  +----------------------------------------------------------+
echo.
call :LOG "--- System Information Scan ---"
%PS% "%TOOLKIT_DIR%system_info.ps1"
call :LOG "System info scan complete."
echo.
echo   System report saved to: %LOG_DIR%\system_report.txt
echo.
echo   Press any key to continue to the main menu...
pause >nul

:: ================================================================
::  MAIN MENU
:: ================================================================
:MAINMENU
cls
echo.
echo  +----------------------------------------------------------+
echo  ^|         Windows 11 Setup Toolkit  v2.0                 ^|
echo  ^|         Tailored profiles for every type of user       ^|
echo  +----------------------------------------------------------+
echo.
echo   How will you mainly use this PC?
echo.
echo   +----------------------------------------------------------+
echo   ^|  1 ^|  Normal / Home    Browser, VLC, Spotify, Steam    ^|
echo   ^|  2 ^|  Productivity     Zoom, Slack, Office, email      ^|
echo   ^|  3 ^|  Developer        VS Code, Git, Node, Python, WSL ^|
echo   ^|  4 ^|  Gaming           Steam, Discord, OBS, game tweaks^|
echo   ^|  5 ^|  Creative         GIMP, Krita, Audacity, OBS      ^|
echo   ^|  6 ^|  Full Install     All 31 apps, every setting      ^|
echo   +----------------------------------------------------------+
echo   ^|  7 ^|  Hybrid           Combine two profiles            ^|
echo   ^|  8 ^|  Custom           Pick individual steps yourself  ^|
echo   +----------------------------------------------------------+
echo   ^|  0 ^|  Exit                                             ^|
echo   +----------------------------------------------------------+
echo.
set "CHOICE="
set /p "CHOICE=   Your choice [0-8]: "
echo.

if "!CHOICE!"=="1" goto INFO_NORMAL
if "!CHOICE!"=="2" goto INFO_PRODUCTIVITY
if "!CHOICE!"=="3" goto INFO_DEVELOPER
if "!CHOICE!"=="4" goto INFO_GAMING
if "!CHOICE!"=="5" goto INFO_CREATIVE
if "!CHOICE!"=="6" goto INFO_FULL
if "!CHOICE!"=="7" goto HYBRID_MENU
if "!CHOICE!"=="8" goto CUSTOM_MENU
if "!CHOICE!"=="0" goto EXIT_SETUP

echo   Invalid choice. Enter 0-8.
timeout /t 2 /nobreak >nul
goto MAINMENU

:: ================================================================
::  PROFILE INFO SCREENS
:: ================================================================

:INFO_NORMAL
cls
echo.
echo  +----------------------------------------------------------+
echo  ^|  Profile: Normal / Home                                 ^|
echo  +----------------------------------------------------------+
echo.
echo   APPS (7):
echo     Google Chrome, Mozilla Firefox, VLC, 7-Zip,
echo     Notepad++, Spotify, Steam
echo.
echo   STANDARD SETTINGS (every profile gets these):
echo     * Remove bloatware  (Xbox, Teams, Clipchamp, Skype...)
echo     * Dark mode system-wide
echo     * Explorer: show extensions, open to This PC
echo     * Taskbar: hide Widgets, Search, Copilot, Chat
echo     * Privacy: telemetry off, advertising ID off
echo     * Services: Fax, Maps, Retail Demo disabled
echo.
echo   POWER PLAN:  High Performance
echo.
echo  +----------------------------------------------------------+
set "CONFIRM=" & set /p "CONFIRM=   Start Normal / Home setup? [Y/N]: "
if /i "!CONFIRM!"=="Y" ( set "PROFILE_NAME=Normal" & goto RUN_CORE )
goto MAINMENU

:INFO_PRODUCTIVITY
cls
echo.
echo  +----------------------------------------------------------+
echo  ^|  Profile: Productivity                                  ^|
echo  +----------------------------------------------------------+
echo.
echo   APPS (12):
echo     Chrome, Firefox, 7-Zip, Notepad++,
echo     LibreOffice, Zoom, Slack, Thunderbird,
echo     Sumatra PDF, ShareX, Notion, Windows Terminal
echo.
echo   STANDARD SETTINGS (every profile gets these):
echo     * Remove bloatware, Dark mode
echo     * Explorer, Taskbar, Privacy tweaks
echo     * Services: Fax, Maps, Retail Demo, Xbox disabled
echo.
echo   POWER PLAN:  High Performance
echo.
echo  +----------------------------------------------------------+
set "CONFIRM=" & set /p "CONFIRM=   Start Productivity setup? [Y/N]: "
if /i "!CONFIRM!"=="Y" ( set "PROFILE_NAME=Productivity" & goto RUN_CORE )
goto MAINMENU

:INFO_DEVELOPER
cls
echo.
echo  +----------------------------------------------------------+
echo  ^|  Profile: Developer                                     ^|
echo  +----------------------------------------------------------+
echo.
echo   APPS (12):
echo     Chrome, VS Code, Git, Node.js LTS, Python 3, FFmpeg,
echo     7-Zip, Windows Terminal, Docker Desktop,
echo     GitHub Desktop, Postman, Notepad++
echo.
echo   STANDARD SETTINGS (every profile gets these):
echo     * Remove bloatware, Dark mode, Explorer, Taskbar
echo     * Privacy tweaks
echo.
echo   DEVELOPER EXTRAS:
echo     * Git: main branch, GCM, aliases, long paths
echo     * npm: global prefix (no UAC), updated
echo     * pip: upgraded + virtualenv/pipenv/black
echo     * VS Code: 15+ extensions + settings.json
echo     * WSL2, Hyper-V, Windows Sandbox, .NET 3.5
echo     * Developer Mode + Long Path support
echo.
echo   POWER PLAN:  Ultimate Performance + HAGS + low-latency MM
echo.
echo   SERVICES DISABLED:  SysMain (Superfetch), Fax, Maps,
echo                       Retail Demo, Xbox (unless Gaming added)
echo.
echo  +----------------------------------------------------------+
set "CONFIRM=" & set /p "CONFIRM=   Start Developer setup? [Y/N]: "
if /i "!CONFIRM!"=="Y" ( set "PROFILE_NAME=Developer" & goto RUN_CORE )
goto MAINMENU

:INFO_GAMING
cls
echo.
echo  +----------------------------------------------------------+
echo  ^|  Profile: Gaming                                        ^|
echo  +----------------------------------------------------------+
echo.
echo   APPS (6):
echo     Steam, Discord, OBS Studio, Chrome, 7-Zip, qBittorrent
echo.
echo   STANDARD SETTINGS (every profile gets these):
echo     * Remove bloatware, Dark mode, Explorer, Taskbar
echo     * Privacy tweaks
echo.
echo   GAMING EXTRAS:
echo     * Ultimate Performance + HAGS enabled
echo     * Game Mode on, Game DVR/capture off
echo     * Low-latency multimedia tuning (GPU/CPU priority)
echo     * SysMain (Superfetch) disabled
echo     * Xbox Live services KEPT (Steam games need them)
echo.
echo   POWER PLAN:  Ultimate Performance
echo.
echo   NOTE: Want coding AND gaming on the same machine?
echo         Pick option 7 (Hybrid) from the main menu.
echo.
echo  +----------------------------------------------------------+
set "CONFIRM=" & set /p "CONFIRM=   Start Gaming setup? [Y/N]: "
if /i "!CONFIRM!"=="Y" ( set "PROFILE_NAME=Gaming" & goto RUN_CORE )
goto MAINMENU

:INFO_CREATIVE
cls
echo.
echo  +----------------------------------------------------------+
echo  ^|  Profile: Creative                                      ^|
echo  +----------------------------------------------------------+
echo.
echo   APPS (11):
echo     OBS Studio, VLC, FFmpeg, Spotify, GIMP, Inkscape,
echo     Audacity, Krita, HandBrake, Chrome, 7-Zip
echo.
echo   STANDARD SETTINGS (every profile gets these):
echo     * Remove bloatware, Dark mode, Explorer, Taskbar
echo     * Privacy tweaks
echo.
echo   CREATIVE EXTRAS:
echo     * Ultimate Performance + HAGS
echo     * Low-latency multimedia tuning (helps audio/video work)
echo     * SysMain disabled (reduces background disk I/O)
echo     * Xbox services disabled
echo.
echo   POWER PLAN:  Ultimate Performance
echo.
echo  +----------------------------------------------------------+
set "CONFIRM=" & set /p "CONFIRM=   Start Creative setup? [Y/N]: "
if /i "!CONFIRM!"=="Y" ( set "PROFILE_NAME=Creative" & goto RUN_CORE )
goto MAINMENU

:INFO_FULL
cls
echo.
echo  +----------------------------------------------------------+
echo  ^|  Profile: Full Install                                  ^|
echo  +----------------------------------------------------------+
echo.
echo   APPS (31 — union of every profile, zero duplicates):
echo     Chrome, Firefox, VLC, 7-Zip, Notepad++, Spotify,
echo     Steam, LibreOffice, Zoom, Slack, Thunderbird, Sumatra,
echo     ShareX, Notion, Windows Terminal, VS Code, Git,
echo     Node.js LTS, Python 3, FFmpeg, Docker Desktop,
echo     GitHub Desktop, Postman, Discord, OBS Studio,
echo     qBittorrent, GIMP, Inkscape, Audacity, Krita, HandBrake
echo.
echo   SETTINGS: Everything from every profile:
echo     * Developer tools, WSL2, Hyper-V, Sandbox, .NET 3.5
echo     * Ultimate Performance + HAGS + Game Mode
echo     * SysMain disabled, Xbox services KEPT (Full has Gaming)
echo     * All privacy, explorer, taskbar, registry tweaks
echo.
echo   POWER PLAN:  Ultimate Performance
echo.
echo  +----------------------------------------------------------+
set "CONFIRM=" & set /p "CONFIRM=   Start Full Install? [Y/N]: "
if /i "!CONFIRM!"=="Y" ( set "PROFILE_NAME=Full" & goto RUN_CORE )
goto MAINMENU

:: ================================================================
::  HYBRID MENU  — combine two profiles
:: ================================================================
:HYBRID_MENU
cls
echo.
echo  +----------------------------------------------------------+
echo  ^|  Hybrid Profile — combine two profiles                  ^|
echo  ^|  (e.g. Developer + Gaming on the same machine)         ^|
echo  +----------------------------------------------------------+
echo.
echo   Pick your PRIMARY profile (defines the app list base):
echo.
echo   1 = Normal         2 = Productivity     3 = Developer
echo   4 = Gaming         5 = Creative
echo.
set "HYBRID_A="
set /p "HYBRID_A=   Primary profile [1-5]: "

if "!HYBRID_A!"=="1" set "P_A=Normal"
if "!HYBRID_A!"=="2" set "P_A=Productivity"
if "!HYBRID_A!"=="3" set "P_A=Developer"
if "!HYBRID_A!"=="4" set "P_A=Gaming"
if "!HYBRID_A!"=="5" set "P_A=Creative"
if not defined P_A ( echo   Invalid. & timeout /t 2 /nobreak >nul & goto HYBRID_MENU )

echo.
echo   Pick your SECONDARY profile (apps + tweaks merged in):
echo.
echo   1 = Normal         2 = Productivity     3 = Developer
echo   4 = Gaming         5 = Creative
echo.
set "HYBRID_B="
set /p "HYBRID_B=   Secondary profile [1-5]: "

if "!HYBRID_B!"=="1" set "P_B=Normal"
if "!HYBRID_B!"=="2" set "P_B=Productivity"
if "!HYBRID_B!"=="3" set "P_B=Developer"
if "!HYBRID_B!"=="4" set "P_B=Gaming"
if "!HYBRID_B!"=="5" set "P_B=Creative"
if not defined P_B ( echo   Invalid. & timeout /t 2 /nobreak >nul & goto HYBRID_MENU )

if "!P_A!"=="!P_B!" (
    echo.
    echo   Both profiles are the same — just pick the single profile
    echo   from the main menu instead.
    timeout /t 3 /nobreak >nul
    goto MAINMENU
)

set "HYBRID_PROFILE=!P_A!,!P_B!"
set "PROFILE_NAME=!P_A!+!P_B!"

cls
echo.
echo  +----------------------------------------------------------+
echo  ^|  Hybrid: !P_A! + !P_B!
echo  +----------------------------------------------------------+
echo.
echo   This will:
echo     * Install apps from BOTH profiles (merged, no duplicates)
echo     * Apply the STRONGER of the two performance tiers
echo     * Apply ALL tweaks relevant to either profile
echo     * Keep Xbox services if Gaming is either profile
echo.
echo  +----------------------------------------------------------+
set "CONFIRM=" & set /p "CONFIRM=   Start Hybrid !P_A!+!P_B! setup? [Y/N]: "
if /i "!CONFIRM!"=="Y" goto RUN_HYBRID
set "HYBRID_PROFILE=" & set "PROFILE_NAME="
goto MAINMENU

:: ================================================================
::  CUSTOM MENU
:: ================================================================
:CUSTOM_MENU
cls
echo.
echo  +----------------------------------------------------------+
echo  ^|  Custom Setup                                           ^|
echo  +----------------------------------------------------------+
echo.
echo   App profile base (defines which apps are installed):
echo   1=Normal  2=Productivity  3=Developer  4=Gaming  5=Creative  6=Full
echo.
set "CUSTOM_PROFILE=Normal"
set "CAPP=" & set /p "CAPP=   App profile [1-6, default=1]: "
if "!CAPP!"=="1" set "CUSTOM_PROFILE=Normal"
if "!CAPP!"=="2" set "CUSTOM_PROFILE=Productivity"
if "!CAPP!"=="3" set "CUSTOM_PROFILE=Developer"
if "!CAPP!"=="4" set "CUSTOM_PROFILE=Gaming"
if "!CAPP!"=="5" set "CUSTOM_PROFILE=Creative"
if "!CAPP!"=="6" set "CUSTOM_PROFILE=Full"
echo.

echo   Select which steps to run (Y/N for each):
echo   --------------------------------------------------------
call :ASK_STEP "Remove Bloatware (Xbox, Teams, Clipchamp...)"   DO_BLOATWARE
call :ASK_STEP "Install Apps  [!CUSTOM_PROFILE! profile]"       DO_APPS
call :ASK_STEP "Enable Dark Mode"                               DO_DARKMODE
call :ASK_STEP "Configure File Explorer"                        DO_EXPLORER
call :ASK_STEP "Configure Taskbar"                              DO_TASKBAR
call :ASK_STEP "Performance Tweaks  [!CUSTOM_PROFILE! tier]"    DO_PERFORMANCE
call :ASK_STEP "Privacy Tweaks"                                 DO_PRIVACY
call :ASK_STEP "Service Optimization  [!CUSTOM_PROFILE!]"       DO_SERVICES
call :ASK_STEP "Developer Tools (Git, npm, pip, VS Code)"       DO_DEVTOOLS
call :ASK_STEP "Windows Features (WSL2, Hyper-V, .NET 3.5)"    DO_FEATURES
call :ASK_STEP "Registry Tweaks (.reg import)"                  DO_REGISTRY

:: Confirm
cls
echo.
echo  +----------------------------------------------------------+
echo  ^|  Custom Setup — Summary                                 ^|
echo  +----------------------------------------------------------+
echo.
echo   App profile : !CUSTOM_PROFILE!
echo   Steps selected:
if "!DO_BLOATWARE!"=="Y"   echo     [*] Remove Bloatware
if "!DO_APPS!"=="Y"        echo     [*] Install Apps
if "!DO_DARKMODE!"=="Y"    echo     [*] Dark Mode
if "!DO_EXPLORER!"=="Y"    echo     [*] Explorer Settings
if "!DO_TASKBAR!"=="Y"     echo     [*] Taskbar Settings
if "!DO_PERFORMANCE!"=="Y" echo     [*] Performance Tweaks
if "!DO_PRIVACY!"=="Y"     echo     [*] Privacy Tweaks
if "!DO_SERVICES!"=="Y"    echo     [*] Service Optimization
if "!DO_DEVTOOLS!"=="Y"    echo     [*] Developer Tools
if "!DO_FEATURES!"=="Y"    echo     [*] Windows Features
if "!DO_REGISTRY!"=="Y"    echo     [*] Registry Tweaks
echo.
set "CONFIRM=" & set /p "CONFIRM=   Run these steps? [Y/N]: "
if /i "!CONFIRM!"=="N" ( set "CUSTOM_PROFILE=" & goto MAINMENU )

set "PROFILE_NAME=!CUSTOM_PROFILE!"
call :LOG "Custom profile: !CUSTOM_PROFILE!"
goto RUN_CUSTOM

:: ================================================================
::  RUN CORE — all named single profiles
:: ================================================================
:RUN_CORE
call :LOG "Running profile: !PROFILE_NAME!"
cls
echo.
echo  +----------------------------------------------------------+
echo   Running: !PROFILE_NAME! Profile
echo   Logs: %LOG_DIR%
echo  +----------------------------------------------------------+
echo.

call :STEP_BLOATWARE
call :STEP_APPS
call :STEP_DARKMODE
call :STEP_EXPLORER
call :STEP_TASKBAR
call :STEP_PERFORMANCE
call :STEP_PRIVACY
call :STEP_SERVICES

if "!PROFILE_NAME!"=="Developer" call :STEP_DEVTOOLS
if "!PROFILE_NAME!"=="Full"      call :STEP_DEVTOOLS
if "!PROFILE_NAME!"=="Developer" call :STEP_FEATURES
if "!PROFILE_NAME!"=="Full"      call :STEP_FEATURES

call :STEP_REGISTRY
goto DONE

:: ================================================================
::  RUN HYBRID — two profiles merged
:: ================================================================
:RUN_HYBRID
call :LOG "Running Hybrid profile: !HYBRID_PROFILE!"
cls
echo.
echo  +----------------------------------------------------------+
echo   Running Hybrid: !PROFILE_NAME!
echo   Logs: %LOG_DIR%
echo  +----------------------------------------------------------+
echo.

:: Bloatware, dark mode, explorer, taskbar, privacy — always
call :STEP_BLOATWARE
call :STEP_DARKMODE
call :STEP_EXPLORER
call :STEP_TASKBAR
call :STEP_PRIVACY

:: Install apps for PRIMARY profile (install_apps handles one profile at a time;
:: we run it twice so both app lists are merged at the WinGet level — already-
:: installed apps are skipped safely on the second pass)
echo   --- Installing apps for profile A: !P_A! ---
call :LOG "--- Installing apps: !P_A! ---"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TOOLKIT_DIR%install_apps.ps1" -Profile "!P_A!"
call :CHK "Apps (!P_A!)"

echo   --- Installing apps for profile B: !P_B! ---
call :LOG "--- Installing apps: !P_B! ---"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TOOLKIT_DIR%install_apps.ps1" -Profile "!P_B!"
call :CHK "Apps (!P_B!)"

:: Performance — use the stronger of the two profiles:
:: If either is a max-perf profile, pass that one.
set "PERF_PROFILE=!P_A!"
for %%M in (Developer Gaming Creative Full) do (
    if "!P_A!"=="%%M" set "PERF_PROFILE=%%M"
    if "!P_B!"=="%%M" set "PERF_PROFILE=%%M"
)
echo   --- Performance tweaks (stronger tier: !PERF_PROFILE!) ---
call :LOG "--- Performance tweaks using tier: !PERF_PROFILE! ---"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TOOLKIT_DIR%performance_tweaks.ps1" -Profile "!PERF_PROFILE!"
call :CHK "Performance (!PERF_PROFILE! tier)"

:: Services — pass both profiles as comma-separated string
echo   --- Service optimization: !HYBRID_PROFILE! ---
call :LOG "--- Service optimization: !HYBRID_PROFILE! ---"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TOOLKIT_DIR%service_optimization.ps1" -Profile "!HYBRID_PROFILE!"
call :CHK "Services (!HYBRID_PROFILE!)"

:: Developer tools + Windows Features — if either profile requests them
for %%D in (Developer Full) do (
    if "!P_A!"=="%%D" call :STEP_DEVTOOLS & call :STEP_FEATURES
    if "!P_B!"=="%%D" call :STEP_DEVTOOLS & call :STEP_FEATURES
)

call :STEP_REGISTRY
goto DONE

:: ================================================================
::  RUN CUSTOM — only selected steps
:: ================================================================
:RUN_CUSTOM
cls
echo.
echo  +----------------------------------------------------------+
echo   Custom Setup Running — Profile: !PROFILE_NAME!
echo   Logs: %LOG_DIR%
echo  +----------------------------------------------------------+
echo.

if "!DO_BLOATWARE!"=="Y"   call :STEP_BLOATWARE
if "!DO_APPS!"=="Y"        call :STEP_APPS
if "!DO_DARKMODE!"=="Y"    call :STEP_DARKMODE
if "!DO_EXPLORER!"=="Y"    call :STEP_EXPLORER
if "!DO_TASKBAR!"=="Y"     call :STEP_TASKBAR
if "!DO_PERFORMANCE!"=="Y" call :STEP_PERFORMANCE
if "!DO_PRIVACY!"=="Y"     call :STEP_PRIVACY
if "!DO_SERVICES!"=="Y"    call :STEP_SERVICES
if "!DO_DEVTOOLS!"=="Y"    call :STEP_DEVTOOLS
if "!DO_FEATURES!"=="Y"    call :STEP_FEATURES
if "!DO_REGISTRY!"=="Y"    call :STEP_REGISTRY
goto DONE

:: ================================================================
::  STEP SUBROUTINES
:: ================================================================

:STEP_BLOATWARE
call :HDR "Removing Bloatware"
%PS% "%TOOLKIT_DIR%remove_bloatware.ps1"
call :CHK "Bloatware removal"
exit /b 0

:STEP_APPS
call :HDR "Installing Applications  [!PROFILE_NAME! profile]"
%PS% "%TOOLKIT_DIR%install_apps.ps1" -Profile "!PROFILE_NAME!"
call :CHK "Application installation"
exit /b 0

:STEP_DARKMODE
call :HDR "Enabling Dark Mode"
%PS% "%TOOLKIT_DIR%dark_mode.ps1"
call :CHK "Dark mode"
exit /b 0

:STEP_EXPLORER
call :HDR "Configuring File Explorer"
%PS% "%TOOLKIT_DIR%explorer_settings.ps1"
call :CHK "Explorer settings"
exit /b 0

:STEP_TASKBAR
call :HDR "Configuring Taskbar"
%PS% "%TOOLKIT_DIR%taskbar_settings.ps1"
call :CHK "Taskbar settings"
exit /b 0

:STEP_PERFORMANCE
call :HDR "Applying Performance Tweaks  [!PROFILE_NAME! tier]"
%PS% "%TOOLKIT_DIR%performance_tweaks.ps1" -Profile "!PROFILE_NAME!"
call :CHK "Performance tweaks"
exit /b 0

:STEP_PRIVACY
call :HDR "Applying Privacy Tweaks"
%PS% "%TOOLKIT_DIR%privacy_tweaks.ps1"
call :CHK "Privacy tweaks"
exit /b 0

:STEP_SERVICES
call :HDR "Optimizing Services  [!PROFILE_NAME!]"
set "_SVC_ARG=!PROFILE_NAME!"
if defined HYBRID_PROFILE set "_SVC_ARG=!HYBRID_PROFILE!"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ^
    "%TOOLKIT_DIR%service_optimization.ps1" -Profile "!_SVC_ARG!"
call :CHK "Service optimization"
exit /b 0

:STEP_DEVTOOLS
call :HDR "Configuring Developer Tools"
%PS% "%TOOLKIT_DIR%developer_tools.ps1"
call :CHK "Developer tools"
exit /b 0

:STEP_FEATURES
call :HDR "Installing Windows Features"
%PS% "%TOOLKIT_DIR%windows_features.ps1"
if !errorlevel! equ 2 set "REBOOT_REQUIRED=1"
call :CHK "Windows features"
exit /b 0

:STEP_REGISTRY
call :HDR "Importing Registry Tweaks"
if exist "%TOOLKIT_DIR%registry_tweaks.reg" (
    reg import "%TOOLKIT_DIR%registry_tweaks.reg" >> "%MASTER_LOG%" 2>&1
    if !errorlevel! equ 0 (
        echo   [OK]  Registry tweaks imported.
        call :LOG "OK: Registry tweaks imported."
    ) else (
        echo   [WARN] Registry import warnings. Check logs.
        call :LOG "WARN: Registry import non-zero exit."
        set /a ERRORS+=1
    )
) else (
    echo   [WARN] registry_tweaks.reg not found in !TOOLKIT_DIR!
    call :LOG "WARN: registry_tweaks.reg not found."
)
echo.
exit /b 0

:: ================================================================
::  DONE
:: ================================================================
:DONE
call :CHECK_PENDING_REBOOT

echo.
echo  +----------------------------------------------------------+
if !ERRORS! gtr 0 (
    echo  ^|  Setup finished with !ERRORS! warning^(s^) — see logs.   ^|
) else (
    echo  ^|  Setup complete — no errors!                          ^|
)
echo  ^|  Profile  : !PROFILE_NAME!
echo  ^|  Logs     : !LOG_DIR!
echo  +----------------------------------------------------------+
echo.
call :LOG "========================================================"
call :LOG "Done. Profile=!PROFILE_NAME!  Warnings=!ERRORS!"
call :LOG "========================================================"

if "!REBOOT_REQUIRED!"=="1" (
    echo   A restart is recommended to finish applying changes.
    echo.
    choice /C YN /T 30 /D N /M "   Restart now? [Y/N — default N in 30s]: "
    if !errorlevel! equ 1 (
        echo.
        echo   Restarting in 10 seconds...  ^(shutdown /a to cancel^)
        call :LOG "User accepted restart."
        shutdown /r /t 10 /c "Windows 11 Setup Toolkit — restart required"
    ) else (
        echo.
        echo   Please restart manually when ready.
        call :LOG "User deferred restart."
        pause
    )
) else (
    pause
)
endlocal
exit /b 0

:: ================================================================
::  EXIT
:: ================================================================
:EXIT_SETUP
echo.
echo   Exiting. No changes were made.
echo.
endlocal
exit /b 0

:: ================================================================
::  HELPER SUBROUTINES
:: ================================================================

:HDR
echo   --------------------------------------------------------
echo    %~1
echo   --------------------------------------------------------
call :LOG "--- %~1 ---"
exit /b 0

:CHK
if !errorlevel! equ 0 (
    echo   [OK]  %~1 completed.
    call :LOG "OK: %~1"
) else (
    echo   [WARN] %~1 finished with warnings ^(exit: !errorlevel!^).
    call :LOG "WARN: %~1  exit=!errorlevel!"
    set /a ERRORS+=1
)
echo.
exit /b 0

:LOG
echo [%date% %time%] %~1 >> "%MASTER_LOG%"
exit /b 0

:ASK_STEP
set "_ANS="
set /p "_ANS=   %~1 [Y/N]? "
if /i "!_ANS!"=="Y" ( set "%~2=Y" ) else ( set "%~2=N" )
exit /b 0

:CHECK_PENDING_REBOOT
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if !errorlevel! equ 0 set "REBOOT_REQUIRED=1"
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" >nul 2>&1
if !errorlevel! equ 0 set "REBOOT_REQUIRED=1"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v "PendingFileRenameOperations" >nul 2>&1
if !errorlevel! equ 0 set "REBOOT_REQUIRED=1"
exit /b 0
