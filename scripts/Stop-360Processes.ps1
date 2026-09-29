<#
.SYNOPSIS
    Stop 360 processes and services before uninstalling.

.DESCRIPTION
    Terminates processes whose name starts with the configured prefixes and
    stops matching services. DRY-RUN BY DEFAULT: nothing is changed unless
    -Execute is supplied.

    If a process or service refuses to stop, that is the normal symptom of the
    360 self-protection kernel driver. Do NOT fight it: delete the driver files
    and reboot (see SKILL.md Phase 5) - after the reboot the protection is gone.

.PARAMETER Execute
    Actually stop processes/services. Without it the script only lists them.

.PARAMETER ProcessPrefixes
    Process name prefixes to treat as 360. Default: 360, 360se, 360Chrome ... handled via '360'.

.PARAMETER ServicePatterns
    Service-name patterns (regex). Default: '^360', '^Q360'.

.PARAMETER LogFile
    Optional log file path.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Stop-360Processes.ps1
    powershell -ExecutionPolicy Bypass -File Stop-360Processes.ps1 -Execute
#>
[CmdletBinding()]
param(
    [switch]$Execute,
    [string[]]$ProcessPrefixes = @('360'),
    [string[]]$ServicePatterns = @('^360', '^Q360'),
    [string]$LogFile
)

$ErrorActionPreference = 'SilentlyContinue'
$script:Log = New-Object System.Collections.Generic.List[string]

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

Say '======================================================================'
Say '  STOP 360 PROCESSES / SERVICES'
Say '======================================================================'
Say ('  Time    : ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  Mode    : ' + $mode)
Say ('  Admin   : ' + (IsAdmin))
Say ''
if (-not $Execute) {
    Say '  This is a preview. Re-run with -Execute to actually stop things.'
    Say '  Services need administrator rights; processes of other users may too.'
    Say ''
}

# ------------------------------------------------------------- processes
Say '[1] PROCESSES'
$procTargets = @()
foreach ($pr in (Get-Process)) {
    foreach ($pre in $ProcessPrefixes) {
        if ($pr.ProcessName -like ($pre + '*')) { $procTargets += $pr; break }
    }
}
if (-not $procTargets) {
    Say '  (none found)'
} else {
    foreach ($pr in $procTargets) {
        $pname = $pr.ProcessName
        $pid2 = $pr.Id
        if ($Execute) {
            try {
                Stop-Process -Id $pid2 -Force -ErrorAction Stop
                Say ('  stopped : ' + $pname + ' (PID ' + $pid2 + ')')
            } catch {
                Say ('  FAILED  : ' + $pname + ' (PID ' + $pid2 + ') -> ' + $_.Exception.Message)
                Say '            hint: self-protection may be active; delete drivers and reboot.'
            }
        } else {
            Say ('  would stop: ' + $pname + ' (PID ' + $pid2 + ')')
        }
    }
}

# ------------------------------------------------------------- services
Say ''
Say '[2] SERVICES'
$svcTargets = @()
foreach ($s in (Get-Service)) {
    foreach ($pat in $ServicePatterns) {
        if ($s.Name -match $pat) { $svcTargets += $s; break }
    }
}
if (-not $svcTargets) {
    Say '  (none found)'
} else {
    foreach ($s in $svcTargets) {
        if ($Execute) {
            try {
                Stop-Service -Name $s.Name -Force -ErrorAction Stop
                Say ('  stopped : ' + $s.Name + ' [' + (Get-Service $s.Name).Status + ']')
            } catch {
                Say ('  FAILED  : ' + $s.Name + ' -> ' + $_.Exception.Message)
                Say '            hint: if it hangs in STOP_PENDING, reboot (Phase 5).'
            }
        } else {
            Say ('  would stop: ' + $s.Name + ' [' + $s.Status + ']')
        }
    }
}

# ------------------------------------------------------------- drivers info
Say ''
Say '[3] DRIVER SERVICES (informational)'
$drv = Get-CimInstance Win32_SystemDriver | Where-Object { $_.Name -match '360' }
if ($drv) {
    foreach ($d in $drv) { Say ('  driver: ' + $d.Name + ' [' + $d.State + '] ' + $d.PathName) }
    Say '  NOTE: driver services normally cannot be stopped while loaded.'
    Say '        Delete the .sys files, then reboot - they will not reload.'
} else {
    Say '  (none found)'
}

Say ''
Say '----------------------------------------------------------------------'
if ($Execute) { Say '  Done. Next: Remove-360Remnants.ps1 -Execute' }
else { Say '  Preview only. Add -Execute when you are ready.' }

if ($LogFile) {
    try {
        $script:Log | Out-File -FilePath $LogFile -Encoding UTF8
        Write-Host ('Log written to: ' + $LogFile)
    } catch {
        Write-Host ('Could not write log: ' + $_.Exception.Message)
    }
}
