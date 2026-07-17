param([string]$Cfg = "", [string]$From = "", [string]$To = "")

# Reorder servers in servers.txt.
#   move.ps1 -From 3 -To 1     direct move (name or number)
#   move.ps1                   interactive: arrows select, Enter grab/drop, Esc done

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$esc = [char]27

if (-not $Cfg) { $Cfg = Join-Path $PSScriptRoot "servers.txt" }
if (-not (Test-Path $Cfg)) { Write-Host "  servers.txt not found."; exit }

$head = @(); $rows = @()
foreach ($l in (Get-Content $Cfg)) {
    $t = $l.Trim()
    if (-not $t -or $t.StartsWith('#')) { $head += $l } else { $rows += $l }
}
if ($rows.Count -lt 2) { Write-Host "  need at least two servers to reorder."; exit }
$n = $rows.Count

function NameOf($line) { ($line -split '\|')[0].Trim() }
function IdxOf($arg) {
    if ($arg -match '^\d+$') {
        $i = [int]$arg - 1
        if ($i -ge 0 -and $i -lt $script:rows.Count) { return $i }
        return -1
    }
    for ($i = 0; $i -lt $script:rows.Count; $i++) {
        if ((NameOf $script:rows[$i]) -ieq $arg) { return $i }
    }
    return -1
}
function Save {
    Set-Content -Path $Cfg -Value ($script:head + $script:rows)
    Write-Host "$esc[92m  order saved.$esc[0m"
}

# ---- direct mode ----
if ($From) {
    $f = IdxOf $From
    if ($f -lt 0) { Write-Host "  no server '$From'."; exit }
    if ($To -notmatch '^\d+$') { Write-Host "  usage: /move <name|number> <new position 1..$n>"; exit }
    $t = [int]$To - 1
    if ($t -lt 0 -or $t -ge $n) { Write-Host "  target position must be 1..$n."; exit }
    $item = $rows[$f]
    $list = [System.Collections.ArrayList]@($rows)
    $list.RemoveAt($f)
    $list.Insert($t, $item)
    $rows = @($list)
    Save
    exit
}

# ---- interactive mode ----
$sel = 0; $grab = $false; $changed = $false
[Console]::CursorVisible = $false
Write-Host ""
Write-Host "$esc[92m  Reorder servers$esc[0m"
Write-Host "$esc[90m  Up/Down move - Enter grab/drop - Esc done$esc[0m"

$first = $true
function Draw {
    if (-not $script:first) { [Console]::Write("$esc[$($script:n)A") }
    $script:first = $false
    for ($i = 0; $i -lt $script:n; $i++) {
        $nm = "{0,2}) {1}" -f ($i + 1), (NameOf $script:rows[$i])
        if ($i -eq $script:sel) {
            $color = if ($script:grab) { "$esc[30;103m" } else { "$esc[30;42m" }   # yellow bg = grabbed
            [Console]::Write("$esc[2K$color   $nm   $esc[0m`r`n")
        } else {
            [Console]::Write("$esc[2K$esc[90m   $nm$esc[0m`r`n")
        }
    }
}

try {
    while ($true) {
        Draw
        $k = [Console]::ReadKey($true)
        switch ($k.Key) {
            'UpArrow' {
                if ($sel -gt 0) {
                    if ($grab) {
                        $t = $rows[$sel - 1]; $rows[$sel - 1] = $rows[$sel]; $rows[$sel] = $t
                        $changed = $true
                    }
                    $sel--
                }
            }
            'DownArrow' {
                if ($sel -lt $n - 1) {
                    if ($grab) {
                        $t = $rows[$sel + 1]; $rows[$sel + 1] = $rows[$sel]; $rows[$sel] = $t
                        $changed = $true
                    }
                    $sel++
                }
            }
            'Enter'  { $grab = -not $grab }
            'Escape' {
                if ($grab) { $grab = $false }
                else {
                    if ($changed) { Save } else { Write-Host "$esc[90m  no changes.$esc[0m" }
                    return
                }
            }
        }
    }
} finally { [Console]::CursorVisible = $true }
