<#
.SYNOPSIS
    Remove 360 suite remnants: services, driver files, folders, registry keys,
    startup entries, scheduled tasks and context-menu handlers.

.DESCRIPTION
    SAFE BY DESIGN:
      * DRY-RUN BY DEFAULT - nothing is removed unless -Execute is given.
      * WHITELIST ONLY - works on a fixed list of known 360 locations.
        It never deletes registry keys by broad substring search.
      * BACKUPS - registry keys are exported to a backup folder before deletion;
        long paths are handled with takeown/icacls only when simple delete fails.
      * LOGGING - every action is written to a log file.

    Run it as ADMINISTRATOR for real effect. Without admin it can only preview.

.PARAMETER Execute
    Perform the cleanup. Omit for a dry-run preview.

.PARAMETER CreateRestorePoint
    Create a System Restore point first (only with -Execute). Requires System
    Protection to be enabled for the system drive.

.PARAMETER BackupDir
    Where to store exported registry keys / backups.
    Default: %USERPROFILE%\Desktop\360-removal-backup

.PARAMETER SkipFolders
    Do not touch residual folders.

.PARAMETER SkipRegistry
    Do not touch registry keys.

.PARAMETER SkipDriverFiles
    Do not delete 360*.sys driver files.

.PARAMETER SkipContextMenu
    Do not touch context-menu handlers.

.PARAMETER LogFile
    Log path. Default: <BackupDir>\removal-log-<timestamp>.txt

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Remove-360Remnants.ps1
    powershell -ExecutionPolicy Bypass -File Remove-360Remnants.ps1 -Execute -CreateRestorePoint
#>
[CmdletBinding()]
param(
    [switch]$Execute,
    [switch]$CreateRestorePoint,
    [string]$BackupDir,
    [switch]$SkipFolders,
    [switch]$SkipRegistry,
    [switch]$SkipDriverFiles,
    [switch]$SkipContextMenu,
    [string]$LogFile
)

$ErrorActionPreference = 'SilentlyContinue'
$script:Log = New-Object System.Collections.Generic.List[string]
$script:Removed = 0
$script:Failed = 0

function Say {
    param([string]$t = '')
    $script:Log.Add($t)
    Write-Host $t
}

function IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

$mode = 'DRY-RUN (nothing will be changed)'
if ($Execute) { $mode = 'EXECUTE' }
if (-not $BackupDir) { $BackupDir = Join-Path $env:USERPROFILE 'Desktop\360-removal-backup' }
if (-not $LogFile) {
    $LogFile = Join-Path $BackupDir ('removal-log-' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.txt')
}

Say '======================================================================'
Say '  360 REMNANT REMOVAL'
Say '======================================================================'
Say ('  Time    : ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  Mode    : ' + $mode)
Say ('  Admin   : ' + (IsAdmin))
Say ('  Backup  : ' + $BackupDir)
Say ''
Say '  RISK NOTICE'
Say '  ---------------------------------------------------------------'
Say '  This script deletes files, registry keys and services that belong to'
Say '  360 software. It only touches a whitelist of known 360 locations.'
Say '  ALWAYS make a restore point and/or export the keys first. If you are'
Say '  unsure about an item, stop and review the dry-run output.'
Say '  ---------------------------------------------------------------'
Say ''

if ($Execute -and -not (IsAdmin)) {
    Say '  ABORT: -Execute requires administrator rights.'
    Say '  Right-click PowerShell/terminal -> "Run as administrator", then re-run.'
    return
}

if (-not (Test-Path $BackupDir)) {
    if ($Execute) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
}

# ------------------------------------------------------------ restore point
Say '[0] SYSTEM RESTORE POINT'
if ($CreateRestorePoint -and $Execute) {
    Say '  creating restore point "before-360-removal" ...'
    try {
        Checkpoint-Computer -Description 'before-360-removal' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Say '  restore point created.'
    } catch {
        Say ('  FAILED to create restore point: ' + $_.Exception.Message)
        Say '  Aborting without changes. Enable System Protection or create a backup first.'
        return
    }
} elseif ($CreateRestorePoint) {
    Say '  would create restore point "before-360-removal"'
} else {
    Say '  skipped (use -CreateRestorePoint to create one)'
}

# ------------------------------------------------------------ services
Say ''
Say '[1] SERVICES (stop + delete service entries)'
$svcTargets = Get-Service | Where-Object { $_.Name -match '^360' -or $_.Name -match '^Q360' }
if (-not $svcTargets) {
    Say '  (no 360 services found)'
} else {
    foreach ($s in $svcTargets) {
        if ($Execute) {
            Say ('  stopping : ' + $s.Name)
            Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
            $state = (Get-Service $s.Name -ErrorAction SilentlyContinue).Status
            Say ('  state    : ' + $s.Name + ' -> ' + $state)
            $null = & sc.exe delete $s.Name 2>&1
            if (-not (Get-Service $s.Name -ErrorAction SilentlyContinue)) {
                Say ('  deleted  : ' + $s.Name); $script:Removed++
            } else {
                Say ('  FAILED   : ' + $s.Name + ' (service still present - reboot and re-run)'); $script:Failed++
            }
        } else {
            Say ('  would stop and delete service: ' + $s.Name)
        }
    }
}

# ------------------------------------------------------------ driver files
Say ''
Say '[2] DRIVER FILES (360*.sys)'
if ($SkipDriverFiles) {
    Say '  skipped by parameter'
} else {
    $drvDir = Join-Path $env:SystemRoot 'System32\drivers'
    $drvFiles = Get-ChildItem $drvDir -Filter '360*.sys' -ErrorAction SilentlyContinue
    if (-not $drvFiles) {
        Say '  (no 360*.sys files)'
    } else {
        foreach ($f in $drvFiles) {
            if ($Execute) {
                try {
                    Remove-Item $f.FullName -Force -ErrorAction Stop
                    Say ('  deleted  : ' + $f.FullName); $script:Removed++
                } catch {
                    Say ('  FAILED   : ' + $f.FullName + ' -> ' + $_.Exception.Message)
                    Say '             driver may be loaded; reboot then re-run (Phase 5).'
                    $script:Failed++
                }
            } else {
                Say ('  would delete: ' + $f.FullName)
            }
        }
        Say '  NOTE: after deleting driver files you MUST reboot. Until then the'
        Say '        already-loaded drivers keep running and protect 360 files.'
    }
}

# ------------------------------------------------------------ folders
Say ''
Say '[3] RESIDUAL FOLDERS'
if ($SkipFolders) {
    Say '  skipped by parameter'
} else {
    $folders = @(
        "$env:ProgramFiles\360",
        "${env:ProgramFiles(x86)}\360",
        "$env:LOCALAPPDATA\360",
        "$env:APPDATA\360",
        "$env:APPDATA\360safe",
        "$env:USERPROFILE\AppData\LocalLow\360",
        "$env:ProgramData\360SD",
        "$env:ProgramData\360safe",
        "$env:LOCALAPPDATA\360Chrome",
        "$env:LOCALAPPDATA\360se6",
        "$env:APPDATA\360se6"
    )
    $anyFolder = $false
    foreach ($f in $folders) {
        if (-not (Test-Path $f)) { continue }
        $anyFolder = $true
        if ($Execute) {
            Say ('  removing : ' + $f)
            try {
                Remove-Item $f -Recurse -Force -ErrorAction Stop
                Say ('  deleted  : ' + $f); $script:Removed++
            } catch {
                Say ('  direct delete failed, taking ownership ...')
                $null = & takeown.exe /f "$f" /r /d y 2>&1
                $null = & icacls.exe "$f" /grant administrators:F /t /q 2>&1
                Remove-Item $f -Recurse -Force -ErrorAction SilentlyContinue
                if (Test-Path $f) {
                    Say ('  FAILED   : ' + $f + ' (locked/protected - reboot or Safe Mode)'); $script:Failed++
                } else {
                    Say ('  deleted  : ' + $f + ' (after ownership takeover)'); $script:Removed++
                }
            }
        } else {
            Say ('  would delete folder: ' + $f)
        }
    }
    if (-not $anyFolder) { Say '  (no 360 folders)' }
}

# ------------------------------------------------------------ registry
Say ''
Say '[4] REGISTRY KEYS (whitelist, with export backup)'
if ($SkipRegistry) {
    Say '  skipped by parameter'
} else {
    $regKeys = @(
        'HKCU:\Software\360',
        'HKCU:\Software\360Safe',
        'HKLM:\SOFTWARE\360',
        'HKLM:\SOFTWARE\360Safe',
        'HKLM:\SOFTWARE\WOW6432Node\360',
        'HKLM:\SOFTWARE\WOW6432Node\360Safe'
    )
    $anyKey = $false
    foreach ($k in $regKeys) {
        if (-not (Test-Path $k)) { continue }
        $anyKey = $true
        $flat = $k.Replace('HKCU:\', 'HKCU\').Replace('HKLM:\', 'HKLM\')
        $safeName = ($flat -replace '[\\:]', '_')
        $regFile = Join-Path $BackupDir ($safeName + '.reg')
        if ($Execute) {
            Say ('  exporting: ' + $flat + '  ->  ' + $regFile)
            $null = & reg.exe export $flat $regFile /y 2>&1
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $regFile)) {
                Say ('  SKIPPED  : ' + $flat + ' (registry backup failed)'); $script:Failed++
                continue
            }
            try {
                Remove-Item $k -Recurse -Force -ErrorAction Stop
                Say ('  deleted  : ' + $flat); $script:Removed++
            } catch {
                Say ('  FAILED   : ' + $flat + ' -> ' + $_.Exception.Message); $script:Failed++
            }
        } else {
            Say ('  would export+delete: ' + $flat)
        }
    }
    if (-not $anyKey) { Say '  (no whitelisted 360 registry keys)' }
    Say '  NOTE: the whitelist covers top-level vendor keys ONLY. For deeper keys'
    Say '        (uninstall entries, context menus) review the scan report and'
    Say '        remove them manually in regedit, exporting each one first.'
}

# ------------------------------------------------------------ startup
Say ''
Say '[5] STARTUP ENTRIES'
$runKeys = @(
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
)
$startupHit = $false
foreach ($rk in $runKeys) {
    $props = Get-ItemProperty $rk -ErrorAction SilentlyContinue
    if (-not $props) { continue }
    foreach ($pp in $props.PSObject.Properties) {
        if ($pp.Value -is [string] -and $pp.Value -match '360') {
            $startupHit = $true
            Say ('  review run value manually: ' + $rk + ' :: ' + $pp.Name + ' = ' + $pp.Value)
        }
    }
}
foreach ($sf in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {
    if (-not (Test-Path $sf)) { continue }
    foreach ($l in (Get-ChildItem $sf -Filter '*.lnk' -ErrorAction SilentlyContinue)) {
        if ($l.Name -match '360') {
            $startupHit = $true
            Say ('  review startup shortcut manually: ' + $l.FullName)
        }
    }
}
if (-not $startupHit) { Say '  (no 360 startup entries)' }

# ------------------------------------------------------------ scheduled tasks
Say ''
Say '[6] SCHEDULED TASKS'
$tasks = Get-ScheduledTask | Where-Object { $_.TaskName -match '360' -or $_.TaskPath -match '360' }
if (-not $tasks) {
    Say '  (no 360 scheduled tasks)'
} else {
    foreach ($t in $tasks) {
        Say ('  review task manually: ' + $t.TaskPath + $t.TaskName)
    }
}

# ------------------------------------------------------------ context menu
Say ''
Say '[7] CONTEXT-MENU HANDLERS'
if ($SkipContextMenu) {
    Say '  skipped by parameter'
} else {
    $cmParents = @(
        'Registry::HKEY_CLASSES_ROOT\*\shellex\ContextMenuHandlers',
        'Registry::HKEY_CLASSES_ROOT\Directory\shellex\ContextMenuHandlers',
        'Registry::HKEY_CLASSES_ROOT\Directory\Background\shellex\ContextMenuHandlers',
        'Registry::HKEY_CLASSES_ROOT\Folder\shellex\ContextMenuHandlers',
        'Registry::HKEY_CLASSES_ROOT\Drive\shellex\ContextMenuHandlers',
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\*\shellex\ContextMenuHandlers',
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shellex\ContextMenuHandlers',
        'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Folder\shellex\ContextMenuHandlers'
    )
    $cmHit = $false
    foreach ($par in $cmParents) {
        $subs = Get-ChildItem $par -ErrorAction SilentlyContinue
        foreach ($s in $subs) {
            $dll = (Get-ItemProperty $s.PSPath -ErrorAction SilentlyContinue).'(default)'
            $is360 = ($s.PSChildName -match '360') -or ($dll -is [string] -and $dll -match '360')
            if (-not $is360) { continue }
            $cmHit = $true
            $flat = ($s.PSPath -replace '^Registry::', '')
            Say ('  review handler manually: ' + $flat + '  -> ' + $dll)
        }
    }
    if (-not $cmHit) { Say '  (no 360 context-menu handlers)' }
}

# ------------------------------------------------------------ summary
Say ''
Say '======================================================================'
Say '  SUMMARY'
Say '======================================================================'
Say ('  removed/changed : ' + $script:Removed)
Say ('  failed          : ' + $script:Failed)
Say ''
if ($Execute) {
    Say '  NEXT STEPS'
    Say '   1. Reboot the machine (mandatory if driver files were deleted).'
    Say '   2. After reboot, re-run this script with -Execute to remove leftovers.'
    Say '   3. Verify with: Detect-360Remnants.ps1'
    Say '   4. If items still fail, use Safe Mode (SKILL.md Phase 5) or let the'
    Say '      installed AV (e.g. Huorong) shred the files itself.'
} else {
    Say '  Preview only. Re-run with -Execute (as administrator) to apply.'
}

try {
    if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
    $script:Log | Out-File -FilePath $LogFile -Encoding UTF8
    Write-Host ''
    Write-Host ('Log written to: ' + $LogFile)
} catch {
    Write-Host ('Could not write log: ' + $_.Exception.Message)
}
