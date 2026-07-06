param(
    [string]$Names = "",
    [string]$Ports = "",
    [switch]$Watch,
    [int]$Interval = 2
)

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# ---- box + glyph chars ----
$TL=[char]0x256D; $TR=[char]0x256E; $BL=[char]0x2570; $BR=[char]0x256F
$H =[char]0x2500; $V =[char]0x2502; $LT=[char]0x251C; $RT=[char]0x2524
$DOT=[char]0x25CF; $RE=[char]0x21BB; $BLK=[char]0x2588; $LGT=[char]0x2591

# ---- ANSI color helpers ----
$e=[char]27
function C($code,$s){ "$e[${code}m$s$e[0m" }
# Only green + red are highlights; borders/labels are neutral gray.
$cGreen=92; $cRed=91; $cGray=90; $cCyan=90; $cYel=92; $cWhite=97

try { $inner = [Console]::WindowWidth - 2 } catch { $inner = 78 }
if ($inner -lt 62) { $inner = 62 }

function Test-Port($p) {
    if (-not $p) { return $false }
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect("127.0.0.1", [int]$p, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne(200)) { $client.EndConnect($iar); return $true }
        return $false
    } catch { return $false } finally { $client.Close() }
}
function Format-Mem($bytes) {
    if (-not $bytes) { return "-" }
    return ("{0:N0} MB" -f ($bytes / 1MB))
}
function Format-Uptime($ms) {
    if (-not $ms) { return "-" }
    $start = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$ms).LocalDateTime
    $span  = (Get-Date) - $start
    if ($span.TotalDays    -ge 1) { return ("{0}d {1}h" -f [int]$span.TotalDays, $span.Hours) }
    if ($span.TotalHours   -ge 1) { return ("{0}h {1}m" -f [int]$span.TotalHours, $span.Minutes) }
    if ($span.TotalMinutes -ge 1) { return ("{0}m {1}s" -f [int]$span.TotalMinutes, $span.Seconds) }
    return ("{0}s" -f [int]$span.TotalSeconds)
}
function CpuBar($pct) {
    $n = [Math]::Min(5, [Math]::Round([double]$pct / 20))
    return ($BLK.ToString() * $n) + ($LGT.ToString() * (5 - $n))
}

# print a framed line: content already has ANSI, $vis = visible length
function Line($colored, $vis) {
    $pad = $inner - $vis
    if ($pad -lt 0) { $pad = 0 }
    Write-Host (C $cCyan $V) -NoNewline
    Write-Host ($colored + (" " * $pad)) -NoNewline
    Write-Host (C $cCyan $V)
}

function Show-Status($list, $portList) {
    # pull pm2 data via node -> tiny TSV
    $rows = @{}
    try {
        $json = & cmd /c "pm2 jlist" 2>$null | Out-String
        $tsv  = $json | & node "$PSScriptRoot\parse.js" 2>$null
        foreach ($ln in ($tsv -split "`n")) {
            if (-not $ln.Trim()) { continue }
            $ff = $ln -split "`t"
            if ($ff.Count -ge 6) { $rows[$ff[0]] = $ff }
        }
    } catch { }

    # ---- header ----
    $clock = (Get-Date).ToString("HH:mm:ss")
    $title = " SERVER LAUNCHER "
    $mid   = $inner - $title.Length - $clock.Length - 3
    if ($mid -lt 1) { $mid = 1 }
    Write-Host (C $cCyan ("$TL$H" + (C $cYel $title) + ($H.ToString() * $mid) + " " + (C $cGray $clock) + " $TR"))

    # ---- column header (PORT pinned right) ----
    $hdrL = "  " + "SERVER".PadRight(19) + "STATUS".PadRight(14) + "CPU".PadRight(13) + "MEM".PadRight(11) + "UPTIME".PadRight(9) + $RE.ToString() + " ".PadRight(4)
    $gapH = $inner - $hdrL.Length - 4
    if ($gapH -lt 1) { $gapH = 1 }
    $hdr = $hdrL + (" " * $gapH) + "PORT"
    Line (C $cGray $hdr) $hdr.Length
    Write-Host (C $cCyan ("$LT" + ($H.ToString() * $inner) + "$RT"))

    $nOn=0; $nErr=0; $nExt=0
    $i = 0
    foreach ($n in $list) {
        $i++
        $port = $null
        if ($portList -and $portList.Count -ge $i) { $port = $portList[$i-1] }
        $f = $rows[$n]

        if ($f -and $f[1] -eq "online") {
            $st="online"; $col=$cGreen; $cpu="$($f[2])%"; $bar=CpuBar $f[2]
            $mem=Format-Mem ([double]$f[3]); $up=Format-Uptime ([int64]$f[4]); $re="$($f[5])"; $nOn++
        } elseif ($f) {
            $st="$($f[1])"; $col=$cRed; $cpu="$($f[2])%"; $bar=CpuBar $f[2]
            $mem=Format-Mem ([double]$f[3]); $up=Format-Uptime ([int64]$f[4]); $re="$($f[5])"; $nErr++
        } elseif (Test-Port $port) {
            $st="ext"; $col=$cGreen; $cpu="-"; $bar="     "; $mem="-"; $up="-"; $re="-"; $nExt++
        } else {
            $st="stopped"; $col=$cGray; $cpu="-"; $bar="     "; $mem="-"; $up="-"; $re="-"
        }

        $pstr = if ($port) { ":$port" } else { "-" }
        $nm    = if ($n.Length -gt 18) { $n.Substring(0,18) } else { $n }
        $namef = $nm.PadRight(17)
        $stf   = $st.PadRight(14)
        $cpuf  = ("$bar " + $cpu).PadRight(13)
        $memf  = $mem.PadRight(11)
        $upf   = $up.PadRight(9)
        $ref   = $re.PadRight(5)

        # left block: "  " + dot + " " + name(17) + status(14) + cpu(13) + mem(11) + up(9) + re(5)
        $visLeft = 2 + 1 + 1 + 17 + 14 + 13 + 11 + 9 + 5
        $gap = $inner - $visLeft - $pstr.Length
        if ($gap -lt 1) { $gap = 1 }

        $colored = "  " + (C $col ($DOT.ToString())) + " " + $namef +
                   (C $col $stf) + (C $cWhite $cpuf) + (C $cWhite $memf) + (C $cGray $upf) + (C $cGray $ref) +
                   (" " * $gap) + (C $cCyan $pstr)
        Line $colored $inner
    }

    # ---- footer ----
    Write-Host (C $cCyan ("$LT" + ($H.ToString() * $inner) + "$RT"))
    $sum = "  " + (C $cGreen "$nOn online") + (C $cGray "  " + [char]0x00B7 + "  ") + (C $cRed "$nErr errored") +
           (C $cGray "  " + [char]0x00B7 + "  ") + (C $cGreen "$nExt external")
    $visSum = 2 + "$nOn online".Length + 6 + "$nErr errored".Length + 6 + "$nExt external".Length
    Line $sum $visSum
    Write-Host (C $cCyan ("$BL" + ($H.ToString() * $inner) + "$BR"))
}

$list = @()
if ($Names) { $list = $Names.Split(',') | Where-Object { $_ -ne "" } }
$plist = @()
if ($Ports) { $plist = $Ports.Split(',') | Where-Object { $_ -ne "" } }

if ($Watch) {
    [Console]::CursorVisible = $false
    try {
        Clear-Host
        while ($true) {
            [Console]::SetCursorPosition(0,0)
            Show-Status $list $plist
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
    Show-Status $list $plist
}
