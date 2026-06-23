<#
.SYNOPSIS
    Deep hardware + system inventory — CPU, GPU, RAM, virtual memory, storage,
    motherboard, BIOS, virtualization support, and (where exposable) GPU power/TGP.
.DESCRIPTION
    Runs first, before any setup step, so the user can see exactly what they're
    working with before picking a profile. Writes a timestamped audit log
    (system_info.log) and a clean human-readable snapshot (system_report.txt)
    that overwrites on every run.

    Every section is wrapped independently so a single failed WMI/CIM query
    (common on some OEM boards) never aborts the rest of the report.
.NOTES
    Does not require Administrator for most data; a few fields (battery wear,
    thermal zone) silently fall back to 'N/A' without elevation or on hardware
    that doesn't expose them — this is expected and not an error.
#>

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------
# Logging / report files
# ----------------------------------------------------------------
$LogDir     = Join-Path $PSScriptRoot 'logs'
$LogFile    = Join-Path $LogDir 'system_info.log'
$ReportFile = Join-Path $LogDir 'system_report.txt'
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }

# Report file is a fresh snapshot every run
"Windows 11 Setup Toolkit — System Report" | Out-File -FilePath $ReportFile -Encoding UTF8 -Force
"Generated : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $ReportFile -Append -Encoding UTF8

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Msg"
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

function Write-SectionHeader {
    param([string]$Title)
    $bar = '-' * 62
    Write-Host ""
    Write-Host "  $bar" -ForegroundColor DarkCyan
    Write-Host "   $Title" -ForegroundColor Cyan
    Write-Host "  $bar" -ForegroundColor DarkCyan
    "`n$bar`n $Title`n$bar" | Out-File -FilePath $ReportFile -Append -Encoding UTF8
    Write-Log "=== $Title ==="
}

function Write-Kv {
    param([string]$Label, [string]$Value, [int]$Width = 28)
    if ([string]::IsNullOrWhiteSpace($Value)) { $Value = 'N/A' }
    $line = "    {0,-$Width}: {1}" -f $Label, $Value
    Write-Host $line
    $line | Out-File -FilePath $ReportFile -Append -Encoding UTF8
}

function Try-Section {
    param([scriptblock]$Block, [string]$Name)
    try {
        & $Block
    } catch {
        Write-Kv 'Status' "Could not read $Name ($($_.Exception.Message))"
        Write-Log "WARN: $Name section failed: $_" 'WARN'
    }
}

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Yellow
Write-Host "   GATHERING SYSTEM INFORMATION — please wait..." -ForegroundColor Yellow
Write-Host "  ============================================================" -ForegroundColor Yellow
Write-Log '============================================================'
Write-Log 'System Information Scan — started'
Write-Log '============================================================'

# ================================================================
# OPERATING SYSTEM
# ================================================================
Write-SectionHeader 'OPERATING SYSTEM'
Try-Section -Name 'OS' -Block {
    $os = Get-CimInstance Win32_OperatingSystem
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue

    $editionId = if ($cv.EditionID) { $cv.EditionID } else { 'Unknown' }
    $displayVer = if ($cv.DisplayVersion) { $cv.DisplayVersion } else { $cv.ReleaseId }

    Write-Kv 'Edition'        "$($os.Caption) ($editionId)"
    Write-Kv 'Version'        "$displayVer (Build $($os.BuildNumber).$($cv.UBR))"
    Write-Kv 'Architecture'   $os.OSArchitecture
    Write-Kv 'Install Date'   $os.InstallDate
    Write-Kv 'Last Boot'      $os.LastBootUpTime

    # Edition capability hint — ties into windows_features.ps1
    $homeLike = $editionId -match 'Core|Home'
    if ($homeLike) {
        Write-Kv 'Hyper-V / Sandbox' 'NOT available on Home edition (Pro/Enterprise required)'
    } else {
        Write-Kv 'Hyper-V / Sandbox' 'Available (edition supports it; CPU virtualization also required)'
    }
}

# ================================================================
# SYSTEM / CHASSIS
# ================================================================
Write-SectionHeader 'SYSTEM'
Try-Section -Name 'System/Chassis' -Block {
    $cs = Get-CimInstance Win32_ComputerSystem
    $enc = Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
    $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue

    $laptopChassisTypes = @(8,9,10,11,12,14,18,21,30,31,32)
    $isLaptop = $false
    if ($enc -and $enc.ChassisTypes) {
        foreach ($t in $enc.ChassisTypes) { if ($laptopChassisTypes -contains $t) { $isLaptop = $true } }
    }
    if (-not $isLaptop) {
        $batt = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($batt) { $isLaptop = $true }
    }

    Write-Kv 'Manufacturer'   $cs.Manufacturer
    Write-Kv 'Model'          $cs.Model
    Write-Kv 'Form Factor'    $(if ($isLaptop) { 'Laptop / Mobile' } else { 'Desktop / Tower' })
    Write-Kv 'Motherboard'    "$($board.Manufacturer) $($board.Product)"
    Write-Kv 'BIOS Version'   $bios.SMBIOSBIOSVersion
    Write-Kv 'BIOS Date'      $(if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('yyyy-MM-dd') } else { 'N/A' })
}

# ================================================================
# CPU
# ================================================================
Write-SectionHeader 'CPU (PROCESSOR)'
Try-Section -Name 'CPU' -Block {
    $cpus = Get-CimInstance Win32_Processor
    $i = 0
    foreach ($cpu in $cpus) {
        $i++
        if ($cpus.Count -gt 1) { Write-Kv "Processor #$i" $cpu.Name }
        else { Write-Kv 'Name' $cpu.Name.Trim() }

        Write-Kv 'Manufacturer'        $cpu.Manufacturer
        Write-Kv 'Physical Cores'      $cpu.NumberOfCores
        Write-Kv 'Logical Processors'  $cpu.NumberOfLogicalProcessors
        Write-Kv 'Base Clock Speed'    "$($cpu.MaxClockSpeed) MHz"
        Write-Kv 'Current Clock Speed' "$($cpu.CurrentClockSpeed) MHz"
        Write-Kv 'L2 Cache'            $(if ($cpu.L2CacheSize) { "$($cpu.L2CacheSize) KB" } else { 'N/A' })
        Write-Kv 'L3 Cache'            $(if ($cpu.L3CacheSize) { "$($cpu.L3CacheSize) KB" } else { 'N/A' })
        Write-Kv 'Socket'              $cpu.SocketDesignation
        Write-Kv 'Architecture'        $(switch ($cpu.Architecture) {
                                            0 {'x86'}; 1 {'MIPS'}; 5 {'ARM'}; 6 {'IA64'}
                                            9 {'x64'}; 12 {'ARM64'}; default {"Code $($cpu.Architecture)"}
                                          })
    }

    # Virtualization firmware check (VT-x / AMD-V) — informs Hyper-V/WSL2/Sandbox availability
    $virtEnabled = $false
    $cpuFirst = $cpus | Select-Object -First 1
    if ($cpuFirst.VirtualizationFirmwareEnabled -eq $true) {
        $virtEnabled = $true
    } else {
        $si = systeminfo 2>&1
        if ($si -match 'Virtualization Enabled In Firmware:\s+Yes') { $virtEnabled = $true }
    }
    Write-Kv 'VT-x / AMD-V (BIOS)' $(if ($virtEnabled) { 'Enabled — Hyper-V / WSL2 / Sandbox can work' }
                                      else { 'Disabled or not detected — enable in BIOS/UEFI for Hyper-V/Sandbox/WSL2' })

    # Best-effort CPU temperature (rarely reliable on consumer boards — heavy caveat)
    try {
        $thermal = Get-CimInstance -Namespace 'root/wmi' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop |
                   Select-Object -First 1
        if ($thermal) {
            $celsius = [math]::Round(($thermal.CurrentTemperature / 10) - 273.15, 1)
            Write-Kv 'CPU/Zone Temp (ACPI)' "$celsius C  (often inaccurate on consumer boards — use HWiNFO for precise readings)"
        } else {
            Write-Kv 'CPU/Zone Temp (ACPI)' 'Not exposed by this board — use HWiNFO/Core Temp for real-time readings'
        }
    } catch {
        Write-Kv 'CPU/Zone Temp (ACPI)' 'Not exposed by this board — use HWiNFO/Core Temp for real-time readings'
    }
}

# ================================================================
# RAM (PHYSICAL MEMORY)
# ================================================================
Write-SectionHeader 'RAM (PHYSICAL MEMORY)'
Try-Section -Name 'RAM' -Block {
    $cs = Get-CimInstance Win32_ComputerSystem
    $sticks = Get-CimInstance Win32_PhysicalMemory
    $array = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue

    $totalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    Write-Kv 'Total Installed' "$totalGB GB"
    Write-Kv 'Slots Used'      "$($sticks.Count) of $($array.MemoryDevices)"

    $i = 0
    foreach ($s in $sticks) {
        $i++
        $capGB = [math]::Round($s.Capacity / 1GB, 2)
        $type  = switch ($s.SMBIOSMemoryType) {
            20 {'DDR'}; 21 {'DDR2'}; 24 {'DDR3'}; 26 {'DDR4'}; 34 {'DDR5'}; default {"Type $($s.SMBIOSMemoryType)"}
        }
        Write-Kv "  Module $i ($($s.DeviceLocator))" "$capGB GB, $type, $($s.Speed) MHz, $($s.Manufacturer)"
    }
}

# ================================================================
# VIRTUAL MEMORY / PAGE FILE
# ================================================================
Write-SectionHeader 'VIRTUAL MEMORY (PAGE FILE)'
Try-Section -Name 'Page File' -Block {
    $cs = Get-CimInstance Win32_ComputerSystem
    $pfUsage = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue

    Write-Kv 'Managed By' $(if ($cs.AutomaticManagedPagefile) { 'Windows (automatic)' } else { 'Manual / custom size' })

    if ($pfUsage) {
        foreach ($pf in $pfUsage) {
            Write-Kv 'Location'        $pf.Name
            Write-Kv 'Allocated Size'  "$($pf.AllocatedBaseSize) MB"
            Write-Kv 'Current Usage'   "$($pf.CurrentUsage) MB"
            Write-Kv 'Peak Usage'      "$($pf.PeakUsage) MB"
        }
    } else {
        Write-Kv 'Status' 'No page file currently allocated (or system-managed with none active)'
    }
}

# ================================================================
# GPU (GRAPHICS)
# ================================================================
Write-SectionHeader 'GPU (GRAPHICS)'
Try-Section -Name 'GPU' -Block {
    $gpus = Get-CimInstance Win32_VideoController

    # WMI's AdapterRAM is a 32-bit DWORD and overflows/wraps for cards with
    # >4GB VRAM — this is the long-standing community workaround using the
    # driver's own registry-reported qwMemorySize (QWORD, accurate).
    $classGuid = '{4d36e968-e325-11ce-bfc1-08002be10318}'
    $regBase   = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$classGuid"
    $regVram   = @()
    if (Test-Path $regBase) {
        Get-ChildItem $regBase -ErrorAction SilentlyContinue | ForEach-Object {
            $qw = (Get-ItemProperty -Path $_.PSPath -Name 'HardwareInformation.qwMemorySize' -ErrorAction SilentlyContinue).'HardwareInformation.qwMemorySize'
            if ($qw) { $regVram += [uint64]$qw }
        }
    }

    $i = 0
    foreach ($gpu in $gpus) {
        $i++
        Write-Kv "Adapter #$i" $gpu.Name

        $wmiRamGB = if ($gpu.AdapterRAM -gt 0) { [math]::Round($gpu.AdapterRAM / 1GB, 2) } else { $null }
        Write-Kv '  VRAM (WMI, may be capped)' $(if ($wmiRamGB) { "$wmiRamGB GB" } else { 'Not reported / capped by 32-bit WMI field' })

        Write-Kv '  Driver Version' $gpu.DriverVersion
        Write-Kv '  Driver Date'    $(if ($gpu.DriverDate) { $gpu.DriverDate.ToString('yyyy-MM-dd') } else { 'N/A' })
        Write-Kv '  Current Mode'   "$($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution) @ $($gpu.CurrentRefreshRate)Hz"
    }

    if ($regVram.Count -gt 0) {
        $accurateGB = [math]::Round((($regVram | Measure-Object -Maximum).Maximum) / 1GB, 2)
        Write-Kv 'Accurate VRAM (registry, largest adapter)' "$accurateGB GB"
        Write-Log "Registry-derived VRAM values (bytes): $($regVram -join ', ')"
    }

    # ---- GPU power / TGP (best-effort, NVIDIA only via nvidia-smi) ----
    $nvidiaSmiPath = "$env:SystemRoot\System32\nvidia-smi.exe"
    $nvidiaSmi = if (Test-Path $nvidiaSmiPath) { $nvidiaSmiPath }
                 else { (Get-Command nvidia-smi -ErrorAction SilentlyContinue).Source }

    if ($nvidiaSmi) {
        try {
            $smi = & $nvidiaSmi --query-gpu=name,power.limit,power.draw,memory.total,temperature.gpu `
                                 --format=csv,noheader,nounits 2>&1
            foreach ($line in $smi) {
                $parts = $line -split ',\s*'
                if ($parts.Count -ge 5) {
                    Write-Kv "NVIDIA: $($parts[0])" "Power Limit (~TGP): $($parts[1])W | Draw: $($parts[2])W | VRAM: $($parts[3])MB | Temp: $($parts[4])C"
                }
            }
            Write-Log 'NVIDIA power data retrieved via nvidia-smi.'
        } catch {
            Write-Kv 'GPU Power / TGP' 'nvidia-smi present but query failed — driver may need a restart'
        }
    } else {
        Write-Kv 'GPU Power / TGP' 'Not exposed via standard Windows APIs for this GPU. NVIDIA: install GeForce driver for nvidia-smi. AMD: use AMD Software Adrenalin. Intel: use Intel Arc Control / Graphics Software.'
    }
}

# ================================================================
# STORAGE
# ================================================================
Write-SectionHeader 'STORAGE'
Try-Section -Name 'Storage' -Block {
    $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    $i = 0
    foreach ($d in $disks) {
        $i++
        $sizeGB = [math]::Round($d.Size / 1GB, 1)
        Write-Kv "Disk #$i" "$($d.FriendlyName)"
        Write-Kv '  Type'        $d.MediaType
        Write-Kv '  Size'        "$sizeGB GB"
        Write-Kv '  Health'      $d.HealthStatus
    }

    Write-Host ''
    $vols = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter }
    foreach ($v in $vols) {
        $freeGB  = [math]::Round($v.SizeRemaining / 1GB, 1)
        $sizeGB  = [math]::Round($v.Size / 1GB, 1)
        Write-Kv "Volume $($v.DriveLetter):" "$freeGB GB free of $sizeGB GB  ($($v.FileSystem))"
    }
}

# ================================================================
# NETWORK (basic)
# ================================================================
Write-SectionHeader 'NETWORK ADAPTERS'
Try-Section -Name 'Network' -Block {
    $adapters = Get-CimInstance Win32_NetworkAdapter -ErrorAction SilentlyContinue |
                Where-Object { $_.PhysicalAdapter -eq $true -and $_.NetConnectionStatus -eq 2 }
    if ($adapters) {
        foreach ($a in $adapters) {
            $speedMbps = if ($a.Speed) { [math]::Round($a.Speed / 1MB, 0) } else { $null }
            Write-Kv $a.Name $(if ($speedMbps) { "Connected, $speedMbps Mbps" } else { 'Connected' })
        }
    } else {
        Write-Kv 'Status' 'No actively connected physical adapters detected'
    }
}

# ================================================================
# BATTERY (laptops only)
# ================================================================
Try-Section -Name 'Battery' -Block {
    $batt = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if ($batt) {
        Write-SectionHeader 'BATTERY'
        foreach ($b in $batt) {
            Write-Kv 'Status'           $b.Status
            Write-Kv 'Charge Remaining' "$($b.EstimatedChargeRemaining)%"

            try {
                $designCap = (Get-CimInstance -Namespace root/wmi -ClassName BatteryStaticData -ErrorAction Stop |
                              Select-Object -First 1).DesignedCapacity
                $fullCap   = (Get-CimInstance -Namespace root/wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop |
                              Select-Object -First 1).FullChargedCapacity
                if ($designCap -and $fullCap) {
                    $health = [math]::Round(($fullCap / $designCap) * 100, 1)
                    Write-Kv 'Battery Health' "$health% of original design capacity"
                }
            } catch {
                Write-Kv 'Battery Health' 'Not exposed by this OEM (try: powercfg /batteryreport)'
            }
        }
    }
}

# ================================================================
# SUMMARY / RECOMMENDATIONS
# ================================================================
Write-SectionHeader 'TOOLKIT RECOMMENDATIONS'
Try-Section -Name 'Recommendations' -Block {
    $cs   = Get-CimInstance Win32_ComputerSystem
    $totalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 0)
    $gpus = Get-CimInstance Win32_VideoController
    $hasDiscrete = $gpus | Where-Object { $_.Name -match 'NVIDIA|AMD|Radeon|GeForce' }
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
    $homeLike = $cv.EditionID -match 'Core|Home'

    if ($totalGB -lt 8) {
        Write-Kv 'RAM' "$totalGB GB — Hyper-V/Sandbox/Docker may feel tight; 16GB+ recommended for Developer/Full profiles"
    } elseif ($totalGB -lt 16) {
        Write-Kv 'RAM' "$totalGB GB — fine for Normal/Productivity/Gaming; Developer/Full workloads will be more comfortable at 16GB+"
    } else {
        Write-Kv 'RAM' "$totalGB GB — comfortable for any profile, including Developer/Full with VMs/containers"
    }

    if ($hasDiscrete) {
        Write-Kv 'GPU' 'Discrete GPU detected — Gaming/Creative profiles will benefit from HAGS and Ultimate Performance tuning'
    } else {
        Write-Kv 'GPU' 'Integrated graphics only — Gaming/Creative profiles will still apply tweaks, but expect modest gains'
    }

    if ($homeLike) {
        Write-Kv 'Edition' 'Home edition — Hyper-V and Windows Sandbox will be skipped automatically; WSL2 still works fine'
    } else {
        Write-Kv 'Edition' 'Pro/Enterprise-class — all optional features (Hyper-V, Sandbox, WSL2) are available'
    }
}

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Yellow
Write-Host "   Full report saved to: $ReportFile" -ForegroundColor Yellow
Write-Host "  ============================================================" -ForegroundColor Yellow
Write-Host ""

Write-Log 'System Information Scan — completed'
exit 0
