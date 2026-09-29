<#
.SYNOPSIS
    Read-only reconnaissance of 360 suite remnants on Windows.

.DESCRIPTION
    Scans (WITHOUT modifying anything):
      - running processes
      - services
      - kernel drivers (Win32_SystemDriver) and minifilter instances (fltmc)
      - known residual folders
      - uninstall registry entries
      - startup items (Run keys / Startup folders / StartupApproved)
      - scheduled tasks
      - shell context-menu handlers
      - browser hijack indicators (policies, Preferences text, .lnk arguments, hosts)
    Use this before ANY cleanup to establish the baseline, and again afterwards
    to verify that the machine is clean.

.PARAMETER OutFile
    Also write the report to this file (UTF-8). Example:
    -OutFile "$env:USERPROFILE\Desktop\360-scan-report.txt"

.PARAMETER IncludeProfileScan
    Also text-scan Edge/Chrome profile files for 360 references (slower).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Detect-360Remnants.ps1

.NOTES
    Output is English/ASCII on purpose: PowerShell 5.1 may garble non-ASCII
    literals depending on console code page.
    This script makes NO changes to the system.
#>
[CmdletBinding()]
param(
    [string]$OutFile,
    [switch]$IncludeProfileScan
)

$ErrorActionPreference = 'SilentlyContinue'
$script:Findings = 0
$script:Text = New-Object System.Collections.Generic.List[string]

function Say {
    param([string]$t = '')
    $script:Text.Add($t)
    Write-Host $t
}

function Section {
    param([string]$title)
    Say ''
    Say ('=' * 68)
    Say ('  ' + $title)
    Say ('=' * 68)
}

function Flag {
    param([string]$t)
    $script:Findings++
    Say ('  [FOUND] ' + $t)
}

function Clean {
    param([string]$t = 'nothing found')
    Say ('  [OK]    ' + $t)
}

# ---------------------------------------------------------------- header
Section '360 REMNANT SCAN  (read-only)'
Say ('  Time      : ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  Computer  : ' + $env:COMPUTERNAME)
Say ('  User      : ' + $env:USERNAME)
$isAdmin = $false
try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    $isAdmin = $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {}
Say ('  Admin     : ' + $isAdmin)

# ---------------------------------------------------------------- processes
Section '[1] PROCESSES'
try {
    $procs = Get-Process | Where-Object { $_.ProcessName -match '^360' -or $_.ProcessName -match '360' }
    if ($procs) {
        foreach ($pr in $procs) { Flag ('process: ' + $pr.ProcessName + ' (PID ' + $pr.Id + ')') }
    } else { Clean 'no 360 processes' }
} catch { Say ('  scan error: ' + $_.Exception.Message) }

# ---------------------------------------------------------------- services
Section '[2] SERVICES'
try {
    $svcs = Get-Service | Where-Object { $_.Name -match '360' -or $_.DisplayName -match '360' }
    if ($svcs) {
        foreach ($s in $svcs) { Flag ('service: ' + $s.Name + ' [' + $s.Status + '] (' + $s.DisplayName + ')') }
    } else { Clean 'no 360 services' }
} catch { Say ('  scan error: ' + $_.Exception.Message) }

# ---------------------------------------------------------------- drivers
Section '[3] KERNEL DRIVERS'
try {
    $drv = Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name -match '360' }
    if ($drv) {
        foreach ($d in $drv) { Flag ('driver service: ' + $d.Name + ' [' + $d.State + '] ' + $d.PathName) }
    } else { Clean 'no 360 driver services' }
} catch { Say ('  scan error: ' + $_.Exception.Message) }

Say ''
Say '  --- minifilter instances (fltmc) ---'
try {
    $flt = & fltmc.exe instances 2>$null
    $hit = $flt | Where-Object { $_ -match '360' }
    if ($hit) { foreach ($h in $hit) { Flag ('minifilter: ' + ($h -replace '\s+', ' ')) } }
    else { Clean 'no 360 minifilter instances' }
} catch { Say '  (fltmc unavailable - needs admin to be fully reliable)' }

try {
    $flt2 = & fltmc.exe filters 2>$null
    $hit2 = $flt2 | Where-Object { $_ -match '360' }
    if ($hit2) { foreach ($h in $hit2) { Flag ('registered filter: ' + ($h -replace '\s+', ' ')) } }
} catch {}

$driverFiles = Get-ChildItem "$env:SystemRoot\System32\drivers" -Filter '360*.sys'
if ($driverFiles) { foreach ($f in $driverFiles) { Flag ('driver file: ' + $f.FullName) } }
else { Clean 'no 360*.sys driver files' }

# ---------------------------------------------------------------- folders
Section '[4] RESIDUAL FOLDERS'
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
$folderHit = $false
foreach ($f in $folders) {
    if (Test-Path $f) {
        $folderHit = $true
        $n = 0
        try { $n = (Get-ChildItem $f -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count } catch {}
        Flag ('folder: ' + $f + '  (items: ' + $n + ')')
    }
}
if (-not $folderHit) { Clean 'no known 360 folders' }

# ---------------------------------------------------------------- uninstall entries
Section '[5] UNINSTALL ENTRIES'
$unKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$uHit = $false
foreach ($k in $unKeys) {
    $items = Get-ItemProperty $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match '360' }
    foreach ($i in $items) { $uHit = $true; Flag ('uninstall entry: ' + $i.DisplayName) }
}
if (-not $uHit) { Clean 'no 360 uninstall entries' }

# ---------------------------------------------------------------- startup
Section '[6] STARTUP ITEMS'
$runKeys = @(
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
)
$runHit = $false
foreach ($rk in $runKeys) {
    $props = Get-ItemProperty $rk -ErrorAction SilentlyContinue
    if ($props) {
        foreach ($pp in $props.PSObject.Properties) {
            if ($pp.Value -is [string] -and $pp.Value -match '360') {
                $runHit = $true
                Flag ('run value: ' + $rk + ' :: ' + $pp.Name + ' = ' + $pp.Value)
            }
        }
    }
}
foreach ($sf in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {
    if (Test-Path $sf) {
        $lnks = Get-ChildItem $sf -Filter '*.lnk' -ErrorAction SilentlyContinue
        foreach ($l in $lnks) {
            if ($l.Name -match '360') { $runHit = $true; Flag ('startup folder item: ' + $l.FullName) }
        }
    }
}
if (-not $runHit) { Clean 'no 360 startup items' }

# ---------------------------------------------------------------- scheduled tasks
Section '[7] SCHEDULED TASKS'
try {
    $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -match '360' -or $_.TaskPath -match '360' }
    if ($tasks) { foreach ($t in $tasks) { Flag ('task: ' + $t.TaskPath + $t.TaskName + ' [' + $t.State + ']') } }
    else { Clean 'no 360 scheduled tasks' }
} catch { Say ('  scan error: ' + $_.Exception.Message) }

# ---------------------------------------------------------------- context menu
Section '[8] CONTEXT-MENU HANDLERS'
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
        if ($s.PSChildName -match '360' -or ($dll -is [string] -and $dll -match '360')) {
            $cmHit = $true
            Flag ('context menu: ' + ($par -replace 'Registry::HKEY_CLASSES_ROOT','HKCR' -replace 'Registry::HKEY_LOCAL_MACHINE','HKLM') + '\' + $s.PSChildName + '  -> ' + $dll)
        }
    }
}
if (-not $cmHit) { Clean 'no 360 context-menu handlers' }

# ---------------------------------------------------------------- browser hijack
Section '[9] BROWSER HIJACK INDICATORS'
$policyKeys = @(
    'HKLM:\SOFTWARE\Policies\Microsoft\Edge',
    'HKLM:\SOFTWARE\Policies\Microsoft\Chrome',
    'HKCU:\SOFTWARE\Policies\Microsoft\Edge',
    'HKCU:\SOFTWARE\Policies\Microsoft\Chrome'
)
$polHit = $false
foreach ($pk in $policyKeys) {
    if (Test-Path $pk) {
        $polHit = $true
        $pnames = (Get-ChildItem $pk -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName) -join ', '
        Flag ('browser policy key exists: ' + $pk + '  (subkeys: ' + $pnames + ')')
    }
}
if (-not $polHit) { Clean 'no browser policy keys' }

Say ''
Say '  --- shortcuts containing 360 / hao.360 ---'
$lnkRoots = @(
    "$env:USERPROFILE\Desktop",
    "$env:PUBLIC\Desktop",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch"
)
$lnkHit = $false
foreach ($root in $lnkRoots) {
    if (-not (Test-Path $root)) { continue }
    $lnks = Get-ChildItem $root -Recurse -Filter '*.lnk' -ErrorAction SilentlyContinue
    foreach ($l in $lnks) {
        try {
            $raw = [System.IO.File]::ReadAllText($l.FullName, [System.Text.Encoding]::Unicode)
            if ($raw -match 'hao\.360' -or $raw -match '360\.cn' -or $raw -match '360se' -or $raw -match '360safe') {
                $lnkHit = $true
                Flag ('hijacked shortcut: ' + $l.FullName)
            }
        } catch {}
    }
}
if (-not $lnkHit) { Clean 'no shortcuts with 360 arguments' }

Say ''
Say '  --- hosts file (non-comment lines) ---'
try {
    $hosts = Get-Content "$env:SystemRoot\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue
    $real = $hosts | Where-Object { $_ -and $_ -notmatch '^\s*#' }
    if ($real) {
        $hits = @($real | Where-Object { $_ -match '360' })
        foreach ($h in $hits) { Flag ('hosts entry with 360: ' + $h.Trim()) }
        if ($hits.Count -eq 0) { Clean 'no 360 hosts entries (other entries omitted for privacy)' }
    } else { Clean 'hosts has no active entries' }
} catch { Say '  (hosts unreadable)' }

if ($IncludeProfileScan) {
    Say ''
    Say '  --- browser profile text scan (360 references) ---'
    $profiles = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
    )
    foreach ($pf in $profiles) {
        if (-not (Test-Path $pf)) { Say ('  [info]  profile not present: ' + $pf); continue }
        $files = Get-ChildItem $pf -Include 'Preferences','Secure Preferences','Local State' -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            try {
                $c = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                if ($c) {
                    $n1 = ([regex]::Matches($c, 'hao\.360')).Count
                    $n2 = ([regex]::Matches($c, '360\.cn')).Count
                    if ($n1 -gt 0 -or $n2 -gt 0) {
                        Flag ($f.Name + ' in ' + (Split-Path $pf -Leaf) + ': hao.360=' + $n1 + ', 360.cn=' + $n2 + '  (history/site data OR hijack - inspect manually)')
                    } else { Say ('  [OK]    ' + $f.Name + ' clean in ' + (Split-Path $pf -Leaf)) }
                }
            } catch {}
        }
    }
}

# ---------------------------------------------------------------- summary
Section 'SUMMARY'
if ($script:Findings -eq 0) {
    Say '  RESULT: CLEAN - no 360 remnants detected by this scan.'
    Say '  (If a browser homepage is still hijacked, re-run Phase 1 of SKILL.md'
    Say '   and inspect shortcut arguments, browser policy keys and Preferences.)'
} else {
    Say ('  RESULT: ' + $script:Findings + ' item(s) found. Review each [FOUND] line above.')
    Say '  Next:'
    Say '    1) STOP and verify every item really belongs to 360.'
    Say '    2) Create a restore point / export affected registry keys.'
    Say '    3) Run Stop-360Processes.ps1 then Remove-360Remnants.ps1 (dry-run first).'
    Say '    4) If drivers/folders cannot be removed, reboot or use Safe Mode (Phase 5).'
}

if ($OutFile) {
    try {
        $script:Text | Out-File -FilePath $OutFile -Encoding UTF8
        Write-Host ''
        Write-Host ('Report written to: ' + $OutFile)
    } catch {
        Write-Host ('Could not write report: ' + $_.Exception.Message)
    }
}
