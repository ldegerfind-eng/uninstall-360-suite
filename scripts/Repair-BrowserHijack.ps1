<#
.SYNOPSIS
    Detect and repair browser homepage/startup hijacking caused by 360
    (hao.360.com / www.360.cn / 360 navigation).

.DESCRIPTION
    Handles the four real hijack vectors:
      1. Launcher shortcuts (.lnk) with an appended URL argument  <- most common
      2. Browser policy registry keys under Policies\Microsoft\{Edge,Chrome}
      3. Report 360 references inside the browser profile for manual review

    DRY-RUN BY DEFAULT. With -Execute it will:
      * back up every file/key it touches into -BackupDir
      * strip hijack arguments from shortcuts
      * report browser policies and profile references for manual review

.PARAMETER Browser
    All | Edge | Chrome   (default: All)

.PARAMETER Execute
    Apply the fixes. Without it: report only.

.PARAMETER BackupDir
    Backup location. Default: %USERPROFILE%\Desktop\360-browser-backup

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Repair-BrowserHijack.ps1
    powershell -ExecutionPolicy Bypass -File Repair-BrowserHijack.ps1 -Execute
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'Edge', 'Chrome')]
    [string]$Browser = 'All',
    [switch]$Execute,
    [string]$BackupDir
)

$ErrorActionPreference = 'SilentlyContinue'
$script:Log = New-Object System.Collections.Generic.List[string]
$script:Hits = 0
$script:Fixed = 0

function Say {
    param([string]$t = '')
    $script:Log.Add($t)
    Write-Host $t
}

function Backup-File {
    param([string]$path)
    if (-not (Test-Path $path)) { return $null }
    if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
    $leaf = Split-Path $path -Leaf
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $dest = Join-Path $BackupDir ($stamp + '_' + $leaf)
    try { Copy-Item $path $dest -Force -ErrorAction Stop; return $dest } catch { return $null }
}

$mode = 'DRY-RUN (nothing will be changed)'
if ($Execute) { $mode = 'EXECUTE' }
if (-not $BackupDir) { $BackupDir = Join-Path $env:USERPROFILE 'Desktop\360-browser-backup' }

Say '======================================================================'
Say '  BROWSER HIJACK REPAIR (360 / hao.360.com)'
Say '======================================================================'
Say ('  Time   : ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Say ('  Mode   : ' + $mode)
Say ('  Target : ' + $Browser)
Say ('  Backup : ' + $BackupDir)
Say ''

# --------------------------------------------------------------- 1. shortcuts
Say '[1] SHORTCUTS (.lnk) WITH APPENDED URL ARGUMENTS'
$lnkRoots = @(
    "$env:USERPROFILE\Desktop",
    "$env:PUBLIC\Desktop",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch",
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
)
$wsh = $null
try { $wsh = New-Object -ComObject WScript.Shell } catch { $wsh = $null }
if (-not $wsh) {
    Say '  NOTE: WScript.Shell COM is unavailable in this environment.'
    Say '        Falling back to a text scan (detect only, cannot auto-fix).'
    Say '        Run this script in a normal PowerShell window as administrator.'
}

$lnkHit = $false
foreach ($root in $lnkRoots) {
    if (-not (Test-Path $root)) { continue }
    foreach ($l in (Get-ChildItem $root -Recurse -Filter '*.lnk' -ErrorAction SilentlyContinue)) {
        $target = $null
        $args2 = $null
        $suspect = $false
        if ($wsh) {
            try {
                $sc = $wsh.CreateShortcut($l.FullName)
                $target = $sc.TargetPath
                $args2 = $sc.Arguments
                $suspect = ($args2 -is [string] -and ($args2 -match 'hao\.360\.com' -or $args2 -match '360\.cn'))
            } catch { $suspect = $false }
        } else {
            try {
                $raw = [System.IO.File]::ReadAllText($l.FullName, [System.Text.Encoding]::Unicode)
                if ($raw -match 'hao\.360' -or $raw -match '360\.cn') { $suspect = $true; $target = '(text scan)' }
            } catch {}
        }
        if (-not $suspect) { continue }
        $lnkHit = $true
        $script:Hits++
        Say ('  [FOUND] ' + $l.FullName)
        Say ('          target    : ' + $target)
        Say ('          arguments : ' + $args2)
        if ($Execute -and $wsh) {
            $bk = Backup-File $l.FullName
            Say ('          backup    : ' + $bk)
            if (-not $bk) {
                Say '          SKIPPED: shortcut backup failed'
                continue
            }
            $newArgs = $args2
            if ($newArgs -is [string]) {
                $newArgs = ($newArgs -replace '(https?://)?(www\.)?(hao\.360\.com|360\.cn)[^\s"]*', '').Trim()
            }
            try {
                $sc2 = $wsh.CreateShortcut($l.FullName)
                $sc2.Arguments = $newArgs
                $sc2.Save()
                Say '          FIXED: hijack argument removed'
                $script:Fixed++
            } catch {
                Say ('          FAILED to rewrite: ' + $_.Exception.Message)
            }
        } elseif ($Execute) {
            Say '          cannot auto-fix without COM - edit manually:'
            Say '          right-click the shortcut -> Properties -> Target, delete the URL part'
        } else {
            Say '          -> would strip the URL argument (backup kept)'
        }
    }
}
if (-not $lnkHit) { Say '  (no hijacked shortcuts found)' }

# --------------------------------------------------------------- 2. policies
Say ''
Say '[2] BROWSER POLICY KEYS'
$polKeys = @()
if ($Browser -eq 'All' -or $Browser -eq 'Edge') {
    $polKeys += 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    $polKeys += 'HKCU:\SOFTWARE\Policies\Microsoft\Edge'
}
if ($Browser -eq 'All' -or $Browser -eq 'Chrome') {
    $polKeys += 'HKLM:\SOFTWARE\Policies\Microsoft\Chrome'
    $polKeys += 'HKCU:\SOFTWARE\Policies\Microsoft\Chrome'
}
$polHit = $false
foreach ($pk in $polKeys) {
    if (-not (Test-Path $pk)) { continue }
    $polHit = $true
    $script:Hits++
    $subs = (Get-ChildItem $pk -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName) -join ', '
    Say ('  [FOUND] ' + $pk + '   (subkeys: ' + $subs + ')')
    Say '          review values manually; this key may contain unrelated policies'
}
if (-not $polHit) { Say '  (no browser policy keys)' }

# --------------------------------------------------------------- 3. profile files
Say ''
Say '[3] PROFILE SETTINGS (homepage / startup page)'
$profiles = @()
if ($Browser -eq 'All' -or $Browser -eq 'Edge') {
    $profiles += @{ name = 'Edge';   dir = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"; proc = 'msedge' }
}
if ($Browser -eq 'All' -or $Browser -eq 'Chrome') {
    $profiles += @{ name = 'Chrome'; dir = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default";    proc = 'chrome' }
}

foreach ($pf in $profiles) {
    if (-not (Test-Path $pf.dir)) {
        Say ('  [info] ' + $pf.name + ' profile not present: ' + $pf.dir)
        continue
    }
    $prefPath = Join-Path $pf.dir 'Preferences'
    if (-not (Test-Path $prefPath)) {
        Say ('  [info] ' + $pf.name + ': Preferences not found')
        continue
    }
    $raw = Get-Content $prefPath -Raw
    $nHao = ([regex]::Matches($raw, 'hao\.360')).Count
    $nCn = ([regex]::Matches($raw, '360\.cn')).Count
    if ($nHao -eq 0 -and $nCn -eq 0) {
        Say ('  [OK]   ' + $pf.name + ': Preferences contains no 360 references')
        continue
    }
    $script:Hits++
    Say ('  [FOUND] ' + $pf.name + ' Preferences: hao.360=' + $nHao + ', 360.cn=' + $nCn)
    Say '          (counts include browsing history / site data, not only hijack settings)'

    Say '          inspect browser startup/homepage settings manually; these may be history only'
}

# --------------------------------------------------------------- 4. manual steps
Say ''
Say '[4] MANUAL STEPS (always available as fallback)'
Say '  Chrome / Edge settings:'
Say '    - Chrome: menu (3 dots) -> Settings -> "On startup" -> Open the New Tab page'
Say '      (or Open a specific page) ; Settings -> Appearance -> Home button'
Say '    - Edge  : edge://settings/startHomeNTP  -> "When Edge starts" -> New Tab page'
Say '    - Reset : edge://settings/reset  |  chrome://settings/reset'
Say '              -> "Restore settings to their original defaults"'
Say '    - Extensions: edge://extensions  |  chrome://extensions'
Say '      Remove unknown ones, especially fake "Flash Player" extensions.'
Say '    - History/site data: Ctrl+Shift+Del -> Cookies and site data + History'
Say ''
Say '  If the homepage STILL returns to 360 after all of the above:'
Say '    - check DNS (use 223.5.5.5 / 119.29.29.29) and the router'
Say '    - check C:\Windows\System32\drivers\etc\hosts for 360 entries'
Say '      (do NOT remove entries that belong to your company software)'
Say '    - scan with Malwarebytes or Kaspersky Free'

Say ''
Say '======================================================================'
Say ('  issues found   : ' + $script:Hits)
Say ('  fixes applied  : ' + $script:Fixed)
if (-not $Execute) { Say '  Preview only. Re-run with -Execute to apply shortcut fixes.' }
Say ('  Backups in     : ' + $BackupDir)
Say '======================================================================'

if ($Execute) { try {
    if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
    $script:Log | Out-File -FilePath (Join-Path $BackupDir 'browser-repair-log.txt') -Encoding UTF8
} catch {} }
