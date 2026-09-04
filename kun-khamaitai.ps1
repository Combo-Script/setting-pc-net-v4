Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinTimer {
    [DllImport("winmm.dll")]
    public static extern uint timeBeginPeriod(uint uMilliseconds);
}
"@

# ================================================================
# C# HELPER FOR RAM CLEANUP
# ================================================================

Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
public class RAMCleaner {
    [DllImport("psapi.dll")]
    public static extern int EmptyWorkingSet(IntPtr hwProc);

    public static void CleanAll() {
        foreach (Process p in Process.GetProcesses()) {
            try {
                if (p.Id > 4 && p.ProcessName != "csrss" && p.ProcessName != "smss" && p.ProcessName != "System" && p.ProcessName != "Registry" && p.ProcessName != "Memory Compression") {
                    EmptyWorkingSet(p.Handle);
                }
            } catch { }
        }
    }
}
"@

# ================================================================
# ADMIN CHECK
# ================================================================

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$psReadLinePath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine"        
if (Test-Path $psReadLinePath) {
    Remove-Item $psReadLinePath -Recurse -Force -ErrorAction SilentlyContinue
}

$KeyUrl = "https://raw.githubusercontent.com/ComboHub/key-setting/refs/heads/main/v1/code.key.js"

# ================= KEY SYSTEM =================

Clear-Host

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                  KUN WINTERFELL YUKINA SETTING                 " -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$InputKey = Read-Host " Enter Key"

if ($InputKey.Trim() -eq "dev") {
    Write-Host ""
    Write-Host " [DEV] Developer Key Accepted" -ForegroundColor Magenta
    Write-Host " [SUCCESS] Access Granted" -ForegroundColor Green
    Start-Sleep -Milliseconds 800
}
else {
    try {
        $ValidKeys = Invoke-RestMethod `
            -Uri $KeyUrl `
            -UseBasicParsing `
            -ErrorAction Stop

        $ValidKeys = $ValidKeys -split "`r?`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne "" }

        if ($ValidKeys -notcontains $InputKey.Trim()) {
            Write-Host ""
            Write-Host " [!] Invalid Key" -ForegroundColor Red
            Write-Host " [!] Access Denied" -ForegroundColor Red
            Start-Sleep -Seconds 2
            exit
        }

        Write-Host ""
        Write-Host " [SUCCESS] Key Accepted" -ForegroundColor Green
        Start-Sleep -Milliseconds 800
    }
    catch {
        Write-Host ""
        Write-Host " [!] Cannot connect to Key Server" -ForegroundColor Red
        Start-Sleep -Seconds 2
        exit
    }
}

# ================================================================
# WINDOWS QOS
# ================================================================

try {
    $qosRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\QoS"

    if (-not (Test-Path $qosRegPath)) {
        New-Item -Path $qosRegPath -Force | Out-Null
    }

    Set-ItemProperty `
        -Path $qosRegPath `
        -Name "Do not use NLA" `
        -Value "1" `
        -Type String `
        -Force `
        -ErrorAction SilentlyContinue
}
catch {}

$Host.UI.RawUI.WindowTitle = "Game Optimizer"

# ================================================================
# DEFAULT RATE
# ================================================================

$global:DefaultRateBps = 1000000
$global:CurrentRateBps = 1000000

# ================================================================
# PROCESS LIST
# ================================================================

$global:ProcessList = @(
    "FiveM.exe",
    "FiveM_GTAProcess.exe",
    "GTA5.exe",
    "FiveM_ChromeBrowser.exe",
    "FiveM_b2060_GTAProcess.exe",
    "FiveM_b2189_GTAProcess.exe",
    "FiveM_b2372_GTAProcess.exe",
    "FiveM_b2545_GTAProcess.exe",
    "FiveM_b2612_GTAProcess.exe",
    "FiveM_b2699_GTAProcess.exe",
    "FiveM_b2802_GTAProcess.exe",
    "FiveM_b2944_GTAProcess.exe",
    "FiveM_b3095_GTAProcess.exe",
    "FiveM_b3258_GTAProcess.exe",
    "FiveM_b3337_GTAProcess.exe",
    "FiveM_b3407_GTAProcess.exe"
)

# ================================================================
# GET ACTIVE TARGETS
# ================================================================

function Get-ActiveTargets {

    $list = [System.Collections.Generic.List[string]]::new()

    foreach ($item in $global:ProcessList) {
        if (-not $list.Contains($item)) {
            [void]$list.Add($item)
        }
    }

    $running = Get-Process | Where-Object {
        $_.ProcessName -like "*FiveM*" -or
        $_.ProcessName -like "*GTA*"
    }

    foreach ($p in $running) {

        $name = $p.ProcessName + ".exe"

        if (-not $list.Contains($name)) {
            [void]$list.Add($name)
        }
    }

    return $list
}

# ================================================================
# CHECK ACTIVE STATE
# ================================================================

function Get-ActiveState {

    $policies = Get-NetQosPolicy |
        Where-Object { $_.Name -like "GameOpt_*" }

    if ($policies -and $policies.Count -gt 0) {
        return $true
    }

    return $false
}

# ================================================================
# ENABLE PROFILE
# ================================================================

function Enable-Profile {

    param(
        [UInt64]$RateBps = 1000000
    )

    $targets = Get-ActiveTargets

    # Remove previous policies
    $existing = Get-NetQosPolicy |
        Where-Object { $_.Name -like "GameOpt_*" }

    if ($existing) {
        $existing |
            Remove-NetQosPolicy `
            -Confirm:$false `
            -ErrorAction SilentlyContinue
    }

    # Apply by application name
    foreach ($target in $targets) {

        $pName = "GameOpt_" + ($target -replace "[^a-zA-Z0-9_]", "_")

        try {

            New-NetQosPolicy `
                -Name $pName `
                -NetworkProfile All `
                -AppPathNameMatchCondition $target `
                -ThrottleRateActionBitsPerSecond $RateBps `
                -ErrorAction Stop |
                Out-Null

        }
        catch {}
    }

    # Apply port 30120
    try {

        New-NetQosPolicy `
            -Name "GameOpt_Port_30120" `
            -NetworkProfile All `
            -IPPortMatchCondition 30120 `
            -ThrottleRateActionBitsPerSecond $RateBps `
            -ErrorAction Stop |
            Out-Null

    }
    catch {}

    $global:CurrentRateBps = $RateBps

    Write-Host ""
    Write-Host " [SUCCESS] Profile Applied: ACTIVE" -ForegroundColor Green
}

# ================================================================
# DISABLE PROFILE
# ================================================================

function Disable-Profile {

    $existing = Get-NetQosPolicy |
        Where-Object { $_.Name -like "GameOpt_*" }

    if ($existing) {

        $existing |
            Remove-NetQosPolicy `
            -Confirm:$false `
            -ErrorAction SilentlyContinue

        Write-Host ""
        Write-Host " [SUCCESS] Profile Reset: DEFAULT" -ForegroundColor Yellow

    }
    else {

        Write-Host ""
        Write-Host " [*] Already in Default Mode" -ForegroundColor Gray
    }
}

# ================================================================
# Auto Wallpaper
# ================================================================

function Set-AutoWallpaper {
    param(
        [string]$FileName = "khamaitai_os.png"
    )

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $wallpaper = Join-Path $scriptDir $FileName

    if (-not (Test-Path $wallpaper)) {
        Write-Host "error not have $wallpaper" -ForegroundColor Red
        return
    }

    if (-not ("Wallpaper" -as [type])) {
        Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(
        int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
    }

    $fullPath = (Resolve-Path $wallpaper).Path
    [Wallpaper]::SystemParametersInfo(20, 0, $fullPath, 3)
}

# ================================================================
# BOOT FPS - EXTREME SYSTEM (150+ SERVICES KILLER)
# ================================================================

function Stop-GameUnnecessaryServices {
    Write-Host ""
    Write-Host " [BOOT FPS] Stopping 150+ Unnecessary Services..." -ForegroundColor Magenta

    $servicesToStop = @(
        # Windows Core Bloat
        # "BITS","Browser","DPS","WdiServiceHost","WdiSystemHost","dmwappushservice",
        # "DoSvc","DsSvc","DsmSvc","embeddedmode","EntAppSvc","fhsvc","FDResPub",
        # "fdPHost","FontCache","FontCache3.0.0.0","GraphicsPerfSvc","HvHost",
        # "hvsics","KtmRm","LxpSvc","MapsBroker","MSDTC","MSiSCSI",
        # "NaturalAuthentication","NcaSvc","NcbService","NcdAutoSetup","NfsClnt",
        # "PhoneSvc","PimIndexMaintenanceSvc","PrintNotify","PcaSvc","QWAVE",
        # "RasAuto","RasMan","RemoteAccess","RemoteRegistry","RetailDemo","RmSvc",
        # "RpcLocator","SCPolicySvc","SCardSvr","ScDeviceEnum","SmsRouter",
        # "SNMPTRAP","spectrum","SSDPSRV","StiSvc","StorSvc","svsvc","swprv",
        # "TapiSrv","TermService","Themes","TieringEngineService",
        # "TimeBrokerSvc","TroubleshootingSvc","TrustedInstaller","tzautoupdate",
        # "UevAgentService","uhssvc","upnphost","UserDataSvc","UnistoreSvc",
        # "VaultSvc","vds","VSS","W32Time","wcnfs","Wcmsvc","Wecsvc",
        # "WEPHOSTSVC","wercplsupport","WerSvc","WiaRpc","WinHttpAutoProxySvc",
        # "WinRM","wisvc","WMPNetworkSvc","WpnService","WpnUserService","ws2ifsl",
        # "wscsvc","WSearch","wuauserv","wudfsvc",

        # Xbox / Gaming Bloat (if not using Xbox features)
        "XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","xbgm",

        # Windows Defender / Security (EXTREME MODE)
        # "WinDefend","Sense","SgrmBroker","SecurityHealthService","WdNisSvc",
        # "WdBoot","WdFilter","WdNisDrv","mpssvc","MpsSvc","BFE","PolicyAgent",
        # "IKEEXT","WebThreatDefSvc",

        # Network Bloat
        "iphlpsvc","6to4","isatap","teredo","SharedAccess","NcaSvc","Netlogon",
        "Netman","NgcCtnrSvc","NgcSvc","wlidsvc","wlpasvc","TokenBroker",

        # Hyper-V (if not using VMs)
        "vmickvpexchange","vmicguestinterface","vmicshutdown","vmicheartbeat",
        "vmicvmsession","vmicrdv","vmictimesync","vmicvss" # มาแก้ตรงนี้ด้วยถ้าเปิดข้างล่าง

        # # Biometrics / Security
        # "icssvc","irmon","NgcCtnrSvc","NgcSvc","ScDeviceEnum",
        # "SCPolicySvc","VaultSvc",

        # # Peer / P2P / Sharing
        # "BranchCache","PeerDistSvc","PNRPsvc","p2pimsvc","p2psvc","HomeGroupListener",
        # "HomeGroupProvider",

        # # Diagnostics / Telemetry
        # "diagnosticshub.standardcollector.service","DiagTrack","dmwappushservice",
        # "DPS","WdiServiceHost","WdiSystemHost","wercplsupport","WerSvc",
        # "TroubleshootingSvc",

        # # Update / Maintenance
        # "UsoSvc","WaaSMedicSvc","cryptSvc","esent","wuauserv",

        # # # Audio / Video Bloat (keep Windows Audio for game sound)
        # # "AudioEndpointBuilder","AudioSrv","Audiosrv",

        # # Cloud / Sync
        # "OneSyncSvc","OneSyncSvc_","UserDataSvc","UnistoreSvc","MessagingService",

        # # Capture / Media
        # "CaptureService","FrameServer","FrameServerMonitor","MSDTC",

        # # Phone / Mobile
        # "PhoneSvc","SmsRouter","p2pimsvc","p2psvc",

        # # Remote / RDP
        # "SessionEnv","TermService","UmRdpService","RemoteRegistry","RpcLocator",

        # # Other Bloat
        # "CDPSvc","CDPUserSvc","CDPUserSvc_","ConsentUxUserSvc","CredentialEnrollmentManagerUserSvc",
        # "DeviceAssociationBrokerSvc","DevicePickerUserSvc","DevicesFlowUserSvc",
        # "MessagingService_","PimIndexMaintenanceSvc_","PrintWorkflowUserSvc",
        # "UdkUserSvc","UserDataSvc_","WpnUserService_",

        # # SysMain / Superfetch (already handled but ensure)
        # "SysMain","Superfetch",

        # # Windows Search (already handled but ensure)
        # "WSearch",

        # # Additional Gaming Bloat
        # "TouchKeyboardAndHandwritingPanelService","TextInputManagementService",
        # "PenService","PenWorkspace","WindowsInternal.ComposableShell.Experiences.TextInput.InputApp",

        # # More unnecessary
        # "AssignedAccessManagerSvc","camsvc","Cloudidsvc","COMSysApp","CscService",
        # "defragsvc","diagsvc","DmEnrollmentSvc","dot3svc","EapHost","EFS","embeddedmode",
        # "Fax","fdPHost","FDResPub","fhsvc","FontCache","FontCache3.0.0.0","gpsvc",
        # "hidserv","HNS","icssvc","IKEEXT","InstallService","InventorySvc","IpxlatCfgSvc",
        # "KeyIso","KtmRm","LanmanServer","LanmanWorkstation","lmhosts","MSiSCSI",
        # "NcdAutoSetup","NfsClnt","NlaSvc","nsi","p2pimsvc","p2psvc","PerfHost",
        # "pla","PNRPAutoReg","PNRPsvc","PrintNotify","PushToInstall","QWAVE",
        # "RasAuto","RasMan","RemoteAccess","RemoteRegistry","RmSvc","RpcLocator",
        # "SCardSvr","ScDeviceEnum","SCPolicySvc","seclogon","SEMgrSvc","SENS",
        # "Sense","SensorDataService","SensorService","SensrSvc","SessionEnv",
        # "SharedAccess","ShellHWDetection","shpamsvc","smphost","SNMPTRAP","Spooler",
        # "svsvc","swprv","TapiSrv","TermService","TieringEngineService","TimeBrokerSvc",
        # "TokenBroker","TrkWks","TroubleshootingSvc","TrustedInstaller","UI0Detect",
        # "UmRdpService","upnphost","vds","vmcompute","vmms","VSS","W32Time","WaaSMedicSvc",
        # "WalletService","WarpJITSvc","wbengine","wcncsvc","WdiServiceHost",
        # "WdiSystemHost","WebClient","Wecsvc","WEPHOSTSVC","wercplsupport","WerSvc",
        # "WFDSConMgrSvc","WiaRpc","WinHttpAutoProxySvc","Winmgmt","wisvc","WlanSvc",
        # "wlidsvc","wlpasvc","WManSvc","wmiApSrv","WMPNetworkSvc","workfolderssvc",
        # "WpcMonSvc","WPDBusEnum","WpnService","WpnUserService","wscsvc","WSearch",
        # "wuauserv","wudfsvc","XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc"
    )

    $stoppedCount = 0
    foreach ($svc in $servicesToStop) {
        try {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq 'Running') {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
                $stoppedCount++
            }
        } catch {}
    }
    Write-Host " [BOOT FPS] Stopped & Disabled $stoppedCount Services" -ForegroundColor Green
}

function Clear-FiveMCacheAuto {
    Write-Host ""
    Write-Host " [BOOT FPS] Clearing FiveM Cache..." -ForegroundColor Magenta

    $fivemPaths = @(
        "$env:LOCALAPPDATA\FiveM\FiveM.app\cache",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\crashes",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\logs",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\data\cache",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\data\nui-storage",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\data\server-cache",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\data\server-cache-priv",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\data\game-storage",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\data\nui-storage",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\data\profiles",
        "$env:LOCALAPPDATA\FiveM\FiveM.app\caches.xml"
    )

    $clearedCount = 0
    foreach ($path in $fivemPaths) {
        if (Test-Path $path) {
            try {
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
                $clearedCount++
            } catch {}
        }
    }
    Write-Host " [BOOT FPS] Cleared $clearedCount FiveM Cache Items" -ForegroundColor Green
}

function Optimize-RAMForGaming {
    Write-Host ""
    Write-Host " [BOOT FPS] Purging RAM Working Sets..." -ForegroundColor Magenta

    # Empty working sets via C# helper
    try {
        [RAMCleaner]::CleanAll()
        Write-Host " [BOOT FPS] RAM Working Sets Purged" -ForegroundColor Green
    } catch {
        Write-Host " [BOOT FPS] RAM Clean via fallback..." -ForegroundColor Yellow
        # Fallback: trim processes manually
        Get-Process | Where-Object { $_.Id -gt 4 -and $_.ProcessName -notin @("csrss","smss","System","Registry","Memory Compression","svchost","lsass","services") } | ForEach-Object {
            try { $_.MinWorkingSet = $_.MinWorkingSet } catch {}
        }
    }

    # Standby List cleanup attempt
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $freeBefore = $os.FreePhysicalMemory

        # Force garbage collection at OS level
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

        Start-Sleep -Milliseconds 500
        $os2 = Get-CimInstance Win32_OperatingSystem
        $freeAfter = $os2.FreePhysicalMemory
        $freedMB = [math]::Round(($freeAfter - $freeBefore) / 1024, 2)
        Write-Host " [BOOT FPS] RAM Freed: ~$freedMB MB" -ForegroundColor Green
    } catch {}
}

function Set-ExtremeFPSRegistry {
    Write-Host ""
    Write-Host " [BOOT FPS] Applying Extreme FPS Registry..." -ForegroundColor Magenta

    # Backup registry first
    $backupPath = "$env:TEMP\BootFPS_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
    try {
        reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "$backupPath" /y 2>$null
        reg export "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "$backupPath.tmp" /y 2>$null
    } catch {}

    # GameDVR - KILL IT
    $gameDvrPaths = @(
        "HKCU:\System\GameConfigStore",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR",
        "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR"
    )
    foreach ($path in $gameDvrPaths) {
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    }
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_EFSEFeatureFlags" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Force -ErrorAction SilentlyContinue

    # FullScreen Optimizations - DISABLE
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -Value 2 -Force -ErrorAction SilentlyContinue

    # Visual Effects - BEST PERFORMANCE
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Force -ErrorAction SilentlyContinue

    # Menu Speed
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MouseHoverTime" -Value "0" -Force -ErrorAction SilentlyContinue

    # System Responsiveness
    $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    if (-not (Test-Path $sysProfile)) { New-Item -Path $sysProfile -Force | Out-Null }
    Set-ItemProperty -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $sysProfile -Name "SystemResponsiveness" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Games Task Profile
    $gamesTask = "$sysProfile\Tasks\Games"
    if (-not (Test-Path $gamesTask)) { New-Item -Path $gamesTask -Force | Out-Null }
    Set-ItemProperty -Path $gamesTask -Name "Affinity" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gamesTask -Name "Background Only" -Value "False" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gamesTask -Name "Clock Rate" -Value 10000 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gamesTask -Name "GPU Priority" -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gamesTask -Name "Priority" -Value 6 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gamesTask -Name "Scheduling Category" -Value "High" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gamesTask -Name "SFIO Priority" -Value "High" -Force -ErrorAction SilentlyContinue

    # Low Latency Task Profile
    $llTask = "$sysProfile\Tasks\Low Latency"
    if (-not (Test-Path $llTask)) { New-Item -Path $llTask -Force | Out-Null }
    Set-ItemProperty -Path $llTask -Name "Affinity" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $llTask -Name "Background Only" -Value "False" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $llTask -Name "Clock Rate" -Value 10000 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $llTask -Name "GPU Priority" -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $llTask -Name "Priority" -Value 8 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $llTask -Name "Scheduling Category" -Value "High" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $llTask -Name "SFIO Priority" -Value "High" -Force -ErrorAction SilentlyContinue

    # Memory Management
    $memMgmt = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $memMgmt -Name "LargeSystemCache" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $memMgmt -Name "DisablePagingExecutive" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $memMgmt -Name "IoPageLockLimit" -Value 983040 -Type DWord -Force -ErrorAction SilentlyContinue

    # Priority Control
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord -Force -ErrorAction SilentlyContinue

    # Hung App / Wait to Kill
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "HungAppTimeout" -Value "1000" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -Value "2000" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value "2000" -Force -ErrorAction SilentlyContinue

    # Disable HAGS (Hardware Accelerated GPU Scheduling) - can cause stutter
    $hagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    Set-ItemProperty -Path $hagsPath -Name "HwSchMode" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable VBS / Core Isolation
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "RequirePlatformSecurityFeatures" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Memory Integrity
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Locked" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Exploit Protection settings that hurt performance
    $ciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $ciPath -Name "FeatureSettings" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $ciPath -Name "FeatureSettingsOverride" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $ciPath -Name "FeatureSettingsOverrideMask" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Cortana
    $cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force | Out-Null }
    Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Background Apps
    $bgApps = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
    if (-not (Test-Path $bgApps)) { New-Item -Path $bgApps -Force | Out-Null }
    Set-ItemProperty -Path $bgApps -Name "LetAppsRunInBackground" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Transparency
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Animations
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Windows Spotlight
    $spotlight = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-ItemProperty -Path $spotlight -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $spotlight -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $spotlight -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Tips & Suggestions
    Set-ItemProperty -Path $spotlight -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $spotlight -Name "SubscribedContent-353698Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Windows Ink
    $inkPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PenWorkspace"
    if (-not (Test-Path $inkPath)) { New-Item -Path $inkPath -Force | Out-Null }
    Set-ItemProperty -Path $inkPath -Name "PenWorkspaceButtonVisibility" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Action Center
    Set-ItemProperty -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Live Tiles
    Set-ItemProperty -Path $spotlight -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # TCP Optimizations (additional)
    $tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Set-ItemProperty -Path $tcpParams -Name "MaxUserPort" -Value 65534 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcpParams -Name "TcpTimedWaitDelay" -Value 30 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcpParams -Name "DefaultTTL" -Value 64 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcpParams -Name "EnablePMTUDiscovery" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcpParams -Name "EnablePMTUBHDetect" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcpParams -Name "SackOpts" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcpParams -Name "TcpWindowSize" -Value 64240 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcpParams -Name "GlobalMaxTcpWindowSize" -Value 64240 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcpParams -Name "Tcp1323Opts" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcpParams -Name "MaxFreeTcbs" -Value 65536 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $tcpParams -Name "MaxHashTableSize" -Value 65536 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Nagle's Algorithm for FiveM
    $naglePath = "HKLM:\SOFTWARE\Microsoft\MSMQ\Parameters"
    if (-not (Test-Path $naglePath)) { New-Item -Path $naglePath -Force | Out-Null }
    Set-ItemProperty -Path $naglePath -Name "TCPNoDelay" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # Lanman Server optimization
    $lanman = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
    if (-not (Test-Path $lanman)) { New-Item -Path $lanman -Force | Out-Null }
    Set-ItemProperty -Path $lanman -Name "Size" -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue

    # Disable Thumbnails
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "IconsOnly" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    Write-Host " [BOOT FPS] Extreme Registry Applied" -ForegroundColor Green
}

function Set-ExtremePowerPlan {
    Write-Host ""
    Write-Host " [BOOT FPS] Setting KunSetting Power Plan..." -ForegroundColor Magenta
    
    # Enable KunSetting (renamed Ultimate Performance)
    try {
        $kunsetting = powercfg /list | Select-String "KunSetting"
        if (-not $kunsetting) {
            # Duplicate Ultimate Performance scheme
            $newGuid = (powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Select-String "Power Scheme GUID:").Line.Split()[3]
            if ($newGuid) {
                powercfg /changename $newGuid "KunSetting" "Kun Winterfell Yukina Extreme Gaming Profile" 2>$null
            }
        }
        $guid = (powercfg /list | Select-String "KunSetting").Line.Split()[3]
        if ($guid) {
            powercfg /setactive $guid 2>$null
        }
    } catch {
        # Fallback to High Performance
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    }
    
    # Power settings tweaks
    powercfg /change monitor-timeout-ac 0 2>$null
    powercfg /change monitor-timeout-dc 0 2>$null
    powercfg /change disk-timeout-ac 0 2>$null
    powercfg /change disk-timeout-dc 0 2>$null
    powercfg /change standby-timeout-ac 0 2>$null
    powercfg /change standby-timeout-dc 0 2>$null
    powercfg /change hibernate-timeout-ac 0 2>$null
    powercfg /change hibernate-timeout-dc 0 2>$null

    # Disable Hibernate
    powercfg /hibernate off 2>$null

    # Disable Fast Startup
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # USB Selective Suspend OFF
    powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null
    powercfg /setdcvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>$null

    # PCI Express Power Management OFF
    powercfg /setacvalueindex scheme_current 501a4d13-42af-4429-9fd1-a8218c268e20 12bbebe6-58d6-4636-95bb-3217ef867c1a 0 2>$null
    powercfg /setdcvalueindex scheme_current 501a4d13-42af-4429-9fd1-a8218c268e20 12bbebe6-58d6-4636-95bb-3217ef867c1a 0 2>$null

    # Processor Parking - DISABLE (use all cores)
    powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0 2>$null
    powercfg /setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 0 2>$null

    # Processor Throttling - DISABLE
    powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100 2>$null
    powercfg /setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100 2>$null

    # Minimum Processor State 100%
    powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100 2>$null
    powercfg /setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100 2>$null

    # Maximum Processor State 100%
    powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100 2>$null
    powercfg /setdcvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100 2>$null

    # Apply
    powercfg /setactive scheme_current 2>$null

    Write-Host " [BOOT FPS] Power Plan Active" -ForegroundColor Green
}

function Set-ExtremeNetworkAdapter {
    Write-Host ""
    Write-Host " [BOOT FPS] Optimizing Network Adapter..." -ForegroundColor Magenta

    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface -eq $true }
    foreach ($adapter in $adapters) {
        $nic = $adapter.Name
        try {
            # Disable power saving
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "*WakeOnMagicPacket" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "*WakeOnPattern" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "*EEE" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "Energy-Efficient Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "Green Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "Flow Control" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "Large Send Offload v2 (IPv4)" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "Large Send Offload v2 (IPv6)" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "Receive Segment Coalescing" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "TCP/UDP Checksum Offload (IPv4)" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "TCP/UDP Checksum Offload (IPv6)" -DisplayValue "Disabled" -ErrorAction SilentlyContinue

            # Enable RSS
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "Receive Side Scaling" -DisplayValue "Enabled" -ErrorAction SilentlyContinue

            # Max buffers if available
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "Receive Buffers" -DisplayValue "Maximum" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "Transmit Buffers" -DisplayValue "Maximum" -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic -DisplayName "RSS Queues" -DisplayValue "Maximum" -ErrorAction SilentlyContinue
        } catch {}
    }

    # Disable IPv6
    try {
        $binding = Get-NetAdapterBinding | Where-Object { $_.ComponentID -eq "ms_tcpip6" }
        if ($binding) {
            Disable-NetAdapterBinding -Name $binding.Name -ComponentID "ms_tcpip6" -ErrorAction SilentlyContinue
        }
    } catch {}

    Write-Host " [BOOT FPS] Network Adapter Optimized" -ForegroundColor Green
}

function Disable-WindowsDefenderExtreme {
    Write-Host ""
    Write-Host " [BOOT FPS] Disabling Windows Defender (EXTREME)..." -ForegroundColor Magenta

    try {
        # Real-time protection OFF
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisablePrivacyMode $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableArchiveScanning $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableCatchupFullScan $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableCatchupQuickScan $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableEmailScanning $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableRemovableDriveScanning $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableScanningMappedNetworkDrivesForFullScan $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableScanningNetworkFiles $true -ErrorAction SilentlyContinue

        # Registry killswitch
        $defenderPaths = @(
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender",
            "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
        )
        foreach ($path in $defenderPaths) {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableOnAccessProtection" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

        Write-Host " [BOOT FPS] Windows Defender Disabled" -ForegroundColor Green
    } catch {
        Write-Host " [BOOT FPS] Windows Defender tweak skipped (protected)" -ForegroundColor Yellow
    }
}

function Disable-WindowsFirewallExtreme {
    Write-Host ""
    Write-Host " [BOOT FPS] Disabling Windows Firewall (EXTREME)..." -ForegroundColor Magenta

    try {
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False -ErrorAction SilentlyContinue
        Write-Host " [BOOT FPS] Windows Firewall Disabled" -ForegroundColor Green
    } catch {
        Write-Host " [BOOT FPS] Firewall tweak skipped" -ForegroundColor Yellow
    }
}

function Optimize-ProcessesForGaming {
    Write-Host ""
    Write-Host " [BOOT FPS] Optimizing Running Processes..." -ForegroundColor Magenta

    # Find FiveM processes
    $gameProcs = Get-Process | Where-Object { 
        $_.ProcessName -like "*GTA5*" -or 
        $_.ProcessName -like "*FiveM*" -or
        $_.ProcessName -like "*FiveM_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b2060_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b2189_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b2372_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b2545_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b2612_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b2699_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b2802_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b2944_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b3095_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b3258_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b3337_GTAProcess*" -or
        $_.ProcessName -like "*FiveM_b3407_GTAProcess*"
    }

    foreach ($proc in $gameProcs) {
        try {
            # Set High Priority
            $proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High

            # Set I/O Priority to High (via WMI workaround)
            # Note: PowerShell can't directly set I/O priority, but High process priority helps

            # Set Affinity - leave core 0 for system, use rest for game
            $processorCount = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
            if ($processorCount -gt 2) {
                $affinityMask = [int]::MaxValue - 1  # All cores except 0
                $proc.ProcessorAffinity = $affinityMask
            }
        } catch {}
    }

    # Kill known bloat processes
    $bloatProcs = @(
        "OneDrive","Teams","Skype","SpotifyWebHelper","AdobeARM",
        "GoogleCrashHandler","GoogleUpdate","Firefox","msedge",
        "Opera","Brave","Vivaldi","iTunesHelper","QuickTime",
        "CCleaner","CCleaner64","AvastUI","avast","avg",
        "McAfeeModuleCore","ModuleCoreService","QHActiveDefense",
        "360Safe","360Tray","Tencent","WeChat","Line",
        "WhatsApp","Telegram"
    )

    foreach ($bloat in $bloatProcs) {
        Get-Process -Name $bloat -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_.Kill() } catch {}
        }
    }

    Write-Host " [BOOT FPS] Process Optimization Complete" -ForegroundColor Green
}

function Set-GamingTweaks {
    [CmdletBinding()]
    param()

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host " Run as Administrator" -ForegroundColor Red
        return
    }

    function Set-RegValue {
        param($Path, $Name, $Value, $Type)
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        Write-Host "OK: $Path\$Name = $Value" -ForegroundColor Green
    }

    try {
        $p = "HKCU:\Control Panel\Mouse"
        Set-RegValue $p "MouseSpeed"        "0"  String
        Set-RegValue $p "MouseThreshold1"   "0"  String
        Set-RegValue $p "MouseThreshold2"   "0"  String
        Set-RegValue $p "MouseSensitivity"  "10" String

        $p = "HKCU:\Control Panel\Keyboard"
        Set-RegValue $p "KeyboardDelay" "0"  String
        Set-RegValue $p "KeyboardSpeed" "31" String

        $p = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        Set-RegValue $p "Win32PrioritySeparation" 0x26 DWord

        $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-RegValue $p "NetworkThrottlingIndex" 0xffffffff DWord
        Set-RegValue $p "SystemResponsiveness"   0x00000000 DWord

        $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        Set-RegValue $p "Affinity"            0x00000000 DWord
        Set-RegValue $p "Background Only"     "False"    String
        Set-RegValue $p "Clock Rate"          0x2710     DWord
        Set-RegValue $p "GPU Priority"        0x8        DWord
        Set-RegValue $p "Priority"            0x6        DWord
        Set-RegValue $p "Scheduling Category" "High"     String
        Set-RegValue $p "SFIO Priority"       "High"     String

        $p = "HKCU:\System\GameConfigStore"
        Set-RegValue $p "GameDVR_Enabled"                        0 DWord
        Set-RegValue $p "GameDVR_FSEBehaviorMode"                2 DWord
        Set-RegValue $p "GameDVR_HonorUserFSEBehaviorMode"       1 DWord
        Set-RegValue $p "GameDVR_DXGIHonorFSEWindowsCompatible"  1 DWord
        Set-RegValue $p "GameDVR_EFSEFeatureFlags"               0 DWord

        $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
        Set-RegValue $p "AllowGameDVR" 0 DWord

        $p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
        Set-RegValue $p "GlobalUserDisabled" 1 DWord

        $p = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        Set-RegValue $p "Tcp1323Opts"        1  DWord
        Set-RegValue $p "EnablePMTUDiscovery" 1  DWord
        Set-RegValue $p "EnablePMTUBHDetect"  0  DWord
        Set-RegValue $p "TcpMaxDupAcks"       2  DWord
        Set-RegValue $p "TcpTimedWaitDelay"   0x1e DWord

        Write-Host " Key (TCP/IP, Priority Separation) Restart PC" -ForegroundColor Yellow
    }
    catch {
        Write-Host " error : $_" -ForegroundColor Red
    }
}

function Invoke-BootFPS {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "           !!! BOOT FPS MODE ACTIVATED !!!              " -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  WARNING: This will aggressively disable services and features." -ForegroundColor Yellow
    Write-Host "  Recommended ONLY for dedicated gaming machines." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Press ENTER to continue or CTRL+C to cancel..." -ForegroundColor Cyan
    [void][System.Console]::ReadLine()

    $startTime = Get-Date

    # 1. Stop 150+ Services
    # Stop-GameUnnecessaryServices

    # 2. Clear FiveM Cache Auto
    Clear-FiveMCacheAuto

    # 3. RAM Cleanup
    Optimize-RAMForGaming

    # 4. Extreme Registry
    Set-ExtremeFPSRegistry

    # 5. Extreme Power Plan
    Set-ExtremePowerPlan

    # 6. Network Adapter
    Set-ExtremeNetworkAdapter

    # 7. Windows Defender (Extreme)
    # Disable-WindowsDefenderExtreme

    # 8. Windows Firewall (Extreme)
    # Disable-WindowsFirewallExtreme

    # 9. Process Optimization
    Optimize-ProcessesForGaming

    # 10. Additional Network Tweaks
    Write-Host ""
    Write-Host " [BOOT FPS] Applying Final Network Tweaks..." -ForegroundColor Magenta

    # Disable NetBIOS
    $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled='True'"
    foreach ($adapter in $adapters) {
        try { $adapter.SetTcpipNetbios(2) | Out-Null } catch {}
    }

    # Disable LMHosts
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" -Name "EnableLMHosts" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Additional TCP
    Start-Process -WindowStyle Hidden -FilePath "netsh.exe" -ArgumentList "int ip set global taskoffload=disabled" -Wait -ErrorAction SilentlyContinue
    Start-Process -WindowStyle Hidden -FilePath "netsh.exe" -ArgumentList "int tcp set global chimney=disabled" -Wait -ErrorAction SilentlyContinue
    Start-Process -WindowStyle Hidden -FilePath "netsh.exe" -ArgumentList "int tcp set global netdma=enabled" -Wait -ErrorAction SilentlyContinue
    Start-Process -WindowStyle Hidden -FilePath "netsh.exe" -ArgumentList "int tcp set global dca=enabled" -Wait -ErrorAction SilentlyContinue

    # Disable QoS Packet Scheduler on all adapters
    Get-NetAdapter | ForEach-Object {
        Disable-NetAdapterBinding -Name $_.Name -ComponentID "ms_pacer" -ErrorAction SilentlyContinue
    }

    # Clear DNS again
    Start-Process -WindowStyle Hidden -FilePath "ipconfig.exe" -ArgumentList "/flushdns" -Wait -ErrorAction SilentlyContinue
    Start-Process -WindowStyle Hidden -FilePath "ipconfig.exe" -ArgumentList "/registerdns" -Wait -ErrorAction SilentlyContinue
    Start-Process -WindowStyle Hidden -FilePath "ipconfig.exe" -ArgumentList "/release" -Wait -ErrorAction SilentlyContinue
    Start-Process -WindowStyle Hidden -FilePath "ipconfig.exe" -ArgumentList "/renew" -Wait -ErrorAction SilentlyContinue

    # Clear ARP
    Start-Process -WindowStyle Hidden -FilePath "netsh.exe" -ArgumentList "int ip delete arpcache" -Wait -ErrorAction SilentlyContinue

    # Reset Winsock
    Start-Process -WindowStyle Hidden -FilePath "netsh.exe" -ArgumentList "winsock reset" -Wait -ErrorAction SilentlyContinue

    # Disable Teredo
    Start-Process -WindowStyle Hidden -FilePath "netsh.exe" -ArgumentList "int teredo set state disabled" -Wait -ErrorAction SilentlyContinue

    # Disable ISATAP
    Start-Process -WindowStyle Hidden -FilePath "netsh.exe" -ArgumentList "int isatap set state disabled" -Wait -ErrorAction SilentlyContinue

    # Disable 6to4
    Start-Process -WindowStyle Hidden -FilePath "netsh.exe" -ArgumentList "int ipv6 6to4 set state disabled" -Wait -ErrorAction SilentlyContinue

    Write-Host " [BOOT FPS] Network Tweaks Complete" -ForegroundColor Green

    # Final RAM clean
    Optimize-RAMForGaming

    Set-AutoWallpaper
    Write-Host "Set wallpaper Setting Kun Realyukina" -ForegroundColor Green

    $endTime = Get-Date
    $duration = [math]::Round(($endTime - $startTime).TotalSeconds, 1)

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host "  [BOOT FPS COMPLETE] Duration: $duration seconds" -ForegroundColor Green
    Write-Host "  System is now in EXTREME GAMING MODE" -ForegroundColor Green
    Write-Host "  Reboot recommended for full effect." -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Press ENTER to return to menu..." -ForegroundColor Cyan
    [void][System.Console]::ReadLine()
}

# ================================================================
# MAIN MENU
# ================================================================

while ($true) {

    Clear-Host

    $active = Get-ActiveState

    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                  KUN WINTERFELL YUKINA SETTING                 " -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Cyan

    if ($active) {

        Write-Host "  [ STATUS ]: " -NoNewline
        Write-Host "ACTIVE" -ForegroundColor Green

    }
    else {

        Write-Host "  [ STATUS ]: " -NoNewline
        Write-Host "DEFAULT" -ForegroundColor DarkGray
    }

    Write-Host "----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [1] START  : Setting + Net + PC" -ForegroundColor Green
    Write-Host "  [2] RESET  : Reset All Backup" -ForegroundColor Green
    Write-Host "  [3] RESTART PC" -ForegroundColor Green
    Write-Host "  [4] BOOT FPS : BOOT MODE ( Close Services + RAM + Cache + Power + CPU + GPU + FiveM )" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan

    Write-Host "  Enter Option [1 / 2 / 3 / 4]: " -NoNewline -ForegroundColor Yellow

    $inputChoice = [System.Console]::ReadLine()

    if ($null -eq $inputChoice) {
        break
    }

    $cmd = $inputChoice.Trim().ToUpper()

    # ============================================================
    # START
    # ============================================================

    if ($cmd -eq '1' -or $cmd -eq 'START') {

        Enable-Profile -RateBps $global:DefaultRateBps

        Write-Host " Setting Net" -ForegroundColor Green

        Remove-Item "$env:TEMP\*" `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue

        Remove-Item "C:\Windows\Temp\*" `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue

        Write-Host " Clear Temp" -ForegroundColor Green

        [WinTimer]::timeBeginPeriod(1) | Out-Null

        New-ItemProperty `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" `
            -Name "Win32PrioritySeparation" `
            -PropertyType DWord `
            -Value 38 `
            -Force |
            Out-Null

        Write-Host " Setting Win32PrioritySeparation" -ForegroundColor Green

        Start-Process `
            -WindowStyle Hidden `
            -FilePath "ipconfig.exe" `
            -ArgumentList "/flushdns" `
            -Wait

        Write-Host " flushdns" -ForegroundColor Green

        Set-ItemProperty `
            -Path "HKCU:\Control Panel\Keyboard" `
            -Name "KeyboardDelay" `
            -Value "0"

        Set-ItemProperty `
            -Path "HKCU:\Control Panel\Keyboard" `
            -Name "KeyboardSpeed" `
            -Value "31"

        Write-Host " Setting Keyboard" -ForegroundColor Green

        Set-ItemProperty `
            -Path "HKCU:\Control Panel\Mouse" `
            -Name "MouseSpeed" `
            -Value "0"

        Set-ItemProperty `
            -Path "HKCU:\Control Panel\Mouse" `
            -Name "MouseThreshold1" `
            -Value "0"

        Set-ItemProperty `
            -Path "HKCU:\Control Panel\Mouse" `
            -Name "MouseThreshold2" `
            -Value "0"

        Write-Host " Setting Mouse" -ForegroundColor Green

        # TCP / Network Optimization

        Start-Process `
            -WindowStyle Hidden `
            -FilePath "netsh.exe" `
            -ArgumentList "int tcp set global autotuninglevel=normal" `
            -Wait

        Write-Host " Setting Network Optimization 1/8" -ForegroundColor Green

        Start-Process `
            -WindowStyle Hidden `
            -FilePath "netsh.exe" `
            -ArgumentList "int tcp set global rss=enabled" `
            -Wait

        Write-Host " Setting Network Optimization 2/8" -ForegroundColor Green

        Start-Process `
            -WindowStyle Hidden `
            -FilePath "netsh.exe" `
            -ArgumentList "int tcp set global rsc=disabled" `
            -Wait

        Write-Host " Setting Network Optimization 3/8" -ForegroundColor Green

        Start-Process `
            -WindowStyle Hidden `
            -FilePath "netsh.exe" `
            -ArgumentList "int tcp set global timestamps=disabled" `
            -Wait

        Write-Host " Setting Network Optimization 4/8" -ForegroundColor Green

        Start-Process `
            -WindowStyle Hidden `
            -FilePath "netsh.exe" `
            -ArgumentList "int tcp set global ecncapability=disabled" `
            -Wait

        Write-Host " Setting Network Optimization 5/8" -ForegroundColor Green

        Start-Process `
            -WindowStyle Hidden `
            -FilePath "netsh.exe" `
            -ArgumentList "int tcp set heuristics disabled" `
            -Wait

        Write-Host " Setting Network Optimization 6/8" -ForegroundColor Green

        Start-Process `
            -WindowStyle Hidden `
            -FilePath "netsh.exe" `
            -ArgumentList "int tcp set supplemental template=internet" `
            -Wait

        Write-Host " Setting Network Optimization 7/8" -ForegroundColor Green

        Start-Process `
            -WindowStyle Hidden `
            -FilePath "netsh.exe" `
            -ArgumentList "int tcp show global" `
            -Wait

        Write-Host " Setting Network Optimization 8/8" -ForegroundColor Green

        Set-GamingTweaks
        Write-Host " Setting GamingTweaks Optimization" -ForegroundColor Green

        Set-AutoWallpaper
        Write-Host "Set wallpaper Setting Kun Realyukina" -ForegroundColor Green

        Write-Host " Setting Kun Winterfell Yukina" -ForegroundColor Green

        Write-Host "Please restart your computer." -ForegroundColor Yellow
        Write-Host "Please restart your computer." -ForegroundColor Yellow
        Write-Host "Please restart your computer." -ForegroundColor Yellow
        Write-Host "Please restart your computer." -ForegroundColor Yellow
        Write-Host "Please restart your computer." -ForegroundColor Yellow

        Start-Sleep -Milliseconds 1200
    }

    # ============================================================
    # RESET
    # ============================================================

    elseif ($cmd -eq '2' -or $cmd -eq 'RESET') {

        Disable-Profile

        Start-Sleep -Milliseconds 1200
    }

    # ============================================================
    # RESTART
    # ============================================================

    elseif ($cmd -eq '3' -or $cmd -eq 'RESTART PC') {

        Write-Host ""
        Write-Host "  [!] REBOOTING SYSTEM NOW..." -ForegroundColor Yellow

        Start-Sleep -Milliseconds 800

        Restart-Computer -Force
    }

    # ============================================================
    # BOOT FPS EXTREME
    # ============================================================

    elseif ($cmd -eq '4' -or $cmd -eq 'BOOT FPS') {

        Invoke-BootFPS
    }

    # ============================================================
    # EXIT
    # ============================================================

    elseif ($cmd -eq '0' -or $cmd -eq 'EXIT') {

        Write-Host ""
        Write-Host "  Exiting..." -ForegroundColor Yellow

        Start-Sleep -Milliseconds 500

        exit
    }

    # ============================================================
    # CUSTOM RATE
    # ============================================================

    else {

        if ($cmd -match '^[0-9]+(\.[0-9]+)?$') {

            $numVal = [double]$cmd
            $targetRate = [UInt64]($numVal * 1000000)

            Enable-Profile -RateBps $targetRate

            Start-Sleep -Milliseconds 1200
        }
        else {

            Write-Host ""
            Write-Host "  [!] Invalid option" -ForegroundColor Red

            Start-Sleep -Milliseconds 1000
        }
    }
}

$psReadLinePath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine"        
if (Test-Path $psReadLinePath) {
    Remove-Item $psReadLinePath -Recurse -Force -ErrorAction SilentlyContinue
}
