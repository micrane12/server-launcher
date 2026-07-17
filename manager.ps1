param(
    [Parameter(Mandatory=$true)][string]$Action,   # start | stop | restart | logs | info | clearlogs
    [string]$Name = ""                             # server name, or "all"
)

$root   = $PSScriptRoot
$cfg    = Join-Path $root "servers.txt"
$pidDir = Join-Path $root ".pids"
$logDir = Join-Path $root "logs"
New-Item -ItemType Directory -Force -Path $pidDir, $logDir | Out-Null

function Get-Servers {
    Get-Content $cfg | ForEach-Object {
        $t = $_.Trim()
        if (-not $t -or $t.StartsWith('#')) { return }
        $p = $_ -split '\|'
        if ($p.Count -lt 4) { return }
        [pscustomobject]@{ Name=$p[0].Trim(); Dir=$p[1].Trim(); Cmd=$p[2].Trim(); Port=$p[3].Trim() }
    }
}
function PidFile($n) { Join-Path $pidDir "$n.pid" }
function LogFile($n) { Join-Path $logDir "$n.log" }
function RunFile($n) { Join-Path $pidDir "run_$n.bat" }

function Port-Pid($port) {
    if (-not $port) { return $null }
    try {
        $c = Get-NetTCPConnection -LocalPort ([int]$port) -State Listen -ErrorAction SilentlyContinue
        if ($c) { return ($c.OwningProcess | Select-Object -First 1) }
    } catch { }
    return $null
}

function Start-One($s) {
    if (Port-Pid $s.Port) { Write-Host "  $($s.Name) is already running on :$($s.Port)"; return }
    $log = LogFile $s.Name
    $run = RunFile $s.Name
    # generated wrapper avoids all quoting headaches
    @(
        "@echo off",
        "cd /d ""$($s.Dir)""",
        "$($s.Cmd) > ""$log"" 2>&1"
    ) | Set-Content -Encoding ASCII $run
    $p = Start-Process -FilePath $run -WindowStyle Hidden -PassThru
    Set-Content (PidFile $s.Name) $p.Id
    Write-Host "  started $($s.Name)  (pid $($p.Id), log: logs\$($s.Name).log)"
}

function Stop-One($s) {
    $stopped = $false
    $pf = PidFile $s.Name
    if (Test-Path $pf) {
        $procId = (Get-Content $pf | Select-Object -First 1)
        if ($procId) { & taskkill /PID $procId /T /F *> $null; $stopped = $true }
        Remove-Item $pf -ErrorAction SilentlyContinue
    }
    # also free the port in case it was started another way
    $pp = Port-Pid $s.Port
    if ($pp) { Stop-Process -Id $pp -Force -ErrorAction SilentlyContinue; $stopped = $true }
    if ($stopped) { Write-Host "  stopped $($s.Name)" } else { Write-Host "  $($s.Name) was not running" }
}

$servers = Get-Servers
$targets = if ($Name -and $Name -ne "all") { $servers | Where-Object { $_.Name -ieq $Name } } else { $servers }

if (-not $targets) { Write-Host "  no server named '$Name'"; exit }

switch ($Action) {
    "start"   { foreach ($s in $targets) { Start-One $s } }
    "stop"    { foreach ($s in $targets) { Stop-One  $s } }
    "restart" { foreach ($s in $targets) { Stop-One $s; Start-Sleep -Milliseconds 400; Start-One $s } }
    "logs"    {
        $s = $targets | Select-Object -First 1
        $log = LogFile $s.Name
        if (-not (Test-Path $log)) { Write-Host "  no log yet for $($s.Name)"; break }
        Write-Host "  tailing logs\$($s.Name).log  (Ctrl+C to stop)`n"
        Get-Content $log -Tail 60 -Wait
    }
    "clearlogs" {
        foreach ($s in $targets) {
            $log = LogFile $s.Name
            if (Test-Path $log) { Clear-Content $log -ErrorAction SilentlyContinue; Write-Host "  cleared logs\$($s.Name).log" }
            else { Write-Host "  no log yet for $($s.Name)" }
        }
    }
    "info" {
        $e=[char]27; $g="$e[92m"; $gray="$e[90m"; $w="$e[97m"; $rst="$e[0m"
        foreach ($s in $targets) {
            $pp = Port-Pid $s.Port
            $proc = if ($pp) { Get-Process -Id $pp -ErrorAction SilentlyContinue } else { $null }
            $status = if ($proc) { "${g}online$rst" } else { "${gray}stopped$rst" }
            Write-Host ""
            Write-Host "  ${w}$($s.Name)$rst   $status"
            Write-Host "  ${gray}folder :$rst $($s.Dir)"
            Write-Host "  ${gray}command:$rst $($s.Cmd)"
            Write-Host "  ${gray}port   :$rst $(if ($s.Port) { ':' + $s.Port } else { '-' })"
            Write-Host "  ${gray}log    :$rst logs\$($s.Name).log"
            if ($proc) {
                $up  = (Get-Date) - $proc.StartTime
                $mem = "{0:N0} MB" -f ($proc.WorkingSet64 / 1MB)
                Write-Host "  ${gray}pid    :$rst $($proc.Id)"
                Write-Host "  ${gray}memory :$rst $mem"
                Write-Host ("  ${gray}uptime :$rst {0}h {1}m {2}s" -f [int]$up.TotalHours, $up.Minutes, $up.Seconds)
            }
            Write-Host ""
        }
    }
    default   { Write-Host "  unknown action: $Action" }
}
