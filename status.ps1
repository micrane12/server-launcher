param(
    [switch]$Watch,
    [int]$Interval = 2
)

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$root = $PSScriptRoot
$cfg  = Join-Path $root "servers.txt"

# ---- box + glyph chars ----
$TL=[char]0x256D; $TR=[char]0x256E; $BL=[char]0x2570; $BR=[char]0x256F
$H =[char]0x2500; $V =[char]0x2502; $LT=[char]0x251C; $RT=[char]0x2524
$DOT=[char]0x25CF; $RE=[char]0x21BB; $BLK=[char]0x2588; $LGT=[char]0x2591

# ---- ANSI colors: only green + red are highlights ----
$e=[char]27
function C($code,$s){ "$e[${code}m$s$e[0m" }
$cGreen=92; $cRed=91; $cGray=90; $cWhite=97; $cTitle=92; $cBorder=90

$cores = [Environment]::ProcessorCount
if (-not $script:prevCpu) { $script:prevCpu = @{} }

function Get-Servers {
    Get-Content $cfg | ForEach-Object {
        $t = $_.Trim()
        if (-not $t -or $t.StartsWith('#')) { return }
        $p = $_ -split '\|'
        if ($p.Count -lt 4) { return }
        [pscustomobject]@{ Name=$p[0].Trim(); Port=$p[3].Trim() }
    }
}
function Port-Pid($port) {
    if (-not $port) { return $null }
    try {
        $c = Get-NetTCPConnection -LocalPort ([int]$port) -State Listen -ErrorAction SilentlyContinue
        if ($c) { return ($c.OwningProcess | Select-Object -First 1) }
    } catch { }
    return $null
}
function Format-Mem($bytes) { if (-not $bytes) { return "-" }; return ("{0:N0} MB" -f ($bytes / 1MB)) }
function Format-Uptime($start) {
    if (-not $start) { return "-" }
    $span = (Get-Date) - $start
    if ($span.TotalDays  -ge 1) { return ("{0}d {1}h" -f [int]$span.TotalDays, $span.Hours) }
    if ($span.TotalHours -ge 1) { return ("{0}h {1}m" -f [int]$span.TotalHours, $span.Minutes) }
    if ($span.TotalMinutes -ge 1){ return ("{0}m {1}s" -f [int]$span.TotalMinutes, $span.Seconds) }
    return ("{0}s" -f [int]$span.TotalSeconds)
}
function CpuBar($pct) {
    $n = [Math]::Min(5, [Math]::Max(0,[Math]::Round([double]$pct / 20)))
    return ($BLK.ToString() * $n) + ($LGT.ToString() * (5 - $n))
}

function Line($colored, $vis) {
    $pad = $script:inner - $vis
    if ($pad -lt 0) { $pad = 0 }
    Write-Host (C $cBorder $V) -NoNewline
    Write-Host ($colored + (" " * $pad)) -NoNewline
    Write-Host (C $cBorder $V)
}

function Show-Status {
    try { $script:inner = [Console]::WindowWidth - 2 } catch { $script:inner = 78 }
    if ($script:inner -lt 62) { $script:inner = 62 }
    $inner = $script:inner

    $list = Get-Servers

    # header
    $clock = (Get-Date).ToString("HH:mm:ss")
    $title = " SERVER LAUNCHER "
    $mid   = $inner - $title.Length - $clock.Length - 3
    if ($mid -lt 1) { $mid = 1 }
    Write-Host (C $cBorder ("$TL$H" + (C $cTitle $title) + ($H.ToString() * $mid) + " " + (C $cGray $clock) + " $TR"))

    # column header (PORT pinned right)
    $hdrL = "  " + "SERVER".PadRight(19) + "STATUS".PadRight(14) + "CPU".PadRight(13) + "MEM".PadRight(11) + "UPTIME".PadRight(9) + $RE.ToString() + " ".PadRight(4)
    $gapH = $inner - $hdrL.Length - 4
    if ($gapH -lt 1) { $gapH = 1 }
    $hdr = $hdrL + (" " * $gapH) + "PORT"
    Line (C $cGray $hdr) $hdr.Length
    Write-Host (C $cBorder ("$LT" + ($H.ToString() * $inner) + "$RT"))

    $nOn = 0; $nOff = 0
    $idx = 0
    foreach ($s in $list) {
        $idx++
        $procId = Port-Pid $s.Port
        $proc = $null
        if ($procId) { $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue }

        if ($proc) {
            $st="online"; $col=$cGreen; $nOn++
            $mem = Format-Mem $proc.WorkingSet64
            $up  = Format-Uptime $proc.StartTime
            # CPU% via delta since last refresh
            $cpuPct = 0
            $now = Get-Date
            $tot = $proc.TotalProcessorTime.TotalSeconds
            $prev = $script:prevCpu[$s.Name]
            if ($prev) {
                $dt = ($now - $prev.T).TotalSeconds
                if ($dt -gt 0) { $cpuPct = [Math]::Round((($tot - $prev.C) / ($dt * $cores)) * 100, 0) }
            }
            if ($cpuPct -lt 0) { $cpuPct = 0 }
            $script:prevCpu[$s.Name] = @{ C=$tot; T=$now }
            $cpu = "$cpuPct%"; $bar = CpuBar $cpuPct
            $re  = "-"
        } else {
            $st="stopped"; $col=$cGray; $nOff++
            $cpu="-"; $bar="     "; $mem="-"; $up="-"; $re="-"
            $script:prevCpu.Remove($s.Name) | Out-Null
        }

        $pstr = if ($s.Port) { ":$($s.Port)" } else { "-" }
        $nm    = if ($s.Name.Length -gt 18) { $s.Name.Substring(0,18) } else { $s.Name }
        $namef = $nm.PadRight(17)
        $stf   = $st.PadRight(14)
        $cpuf  = ("$bar " + $cpu).PadRight(13)
        $memf  = $mem.PadRight(11)
        $upf   = $up.PadRight(9)
        $ref   = $re.PadRight(5)

        $visLeft = 2 + 1 + 1 + 17 + 14 + 13 + 11 + 9 + 5
        $gap = $inner - $visLeft - $pstr.Length
        if ($gap -lt 1) { $gap = 1 }

        $colored = "  " + (C $col ($DOT.ToString())) + " " + $namef +
                   (C $col $stf) + (C $cWhite $cpuf) + (C $cWhite $memf) + (C $cGray $upf) + (C $cGray $ref) +
                   (" " * $gap) + (C $cGray $pstr)
        Line $colored $inner
    }

    Write-Host (C $cBorder ("$LT" + ($H.ToString() * $inner) + "$RT"))
    $sum = "  " + (C $cGreen "$nOn online") + (C $cGray ("  " + [char]0x00B7 + "  ")) + (C $cGray "$nOff stopped")
    $visSum = 2 + "$nOn online".Length + 6 + "$nOff stopped".Length
    Line $sum $visSum
    Write-Host (C $cBorder ("$BL" + ($H.ToString() * $inner) + "$BR"))
}

if ($Watch) {
    [Console]::CursorVisible = $false
    try {
        Clear-Host
        while ($true) {
            [Console]::SetCursorPosition(0,0)
            Show-Status
            Write-Host (C $cGray "  refreshing every ${Interval}s  -  press any key to stop      ")
            $t = 0
            while ($t -lt ($Interval * 10)) {
                if ([Console]::KeyAvailable) { [Console]::ReadKey($true) | Out-Null; Write-Host ""; return }
                Start-Sleep -Milliseconds 100
                $t++
            }
        }
    } finally { [Console]::CursorVisible = $true }
} else {
    Show-Status
}
