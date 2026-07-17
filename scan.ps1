param(
    [string]$Root = "",
    [string]$Cfg  = ""
)

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$e=[char]27
function C($code,$s){ "$e[${code}m$s$e[0m" }

if (-not $Cfg) { $Cfg = Join-Path $PSScriptRoot "servers.txt" }

# ask for a root folder if none given (handles spaces fine at a PS prompt)
$default = "C:\Dev"
if (-not $Root) {
    $inp = Read-Host "  Folder to scan [$default]"
    if ($inp) { $Root = $inp } else { $Root = $default }
}
# relative input like "bulk-sender" -> resolve against the default root
if (-not (Test-Path $Root) -and -not [System.IO.Path]::IsPathRooted($Root)) {
    $try = Join-Path $default $Root
    if (Test-Path $try) { $Root = $try }
}
if (-not (Test-Path $Root)) { Write-Host (C 91 "  folder not found: $Root"); return }

# existing servers (skip anything already added, matched by folder path)
$existingDirs = @()
if (Test-Path $Cfg) {
    Get-Content $Cfg | ForEach-Object {
        $t = $_.Trim(); if (-not $t -or $t.StartsWith('#')) { return }
        $p = $_ -split '\|'; if ($p.Count -ge 2) { $existingDirs += $p[1].Trim().TrimEnd('\').ToLower() }
    }
}

function Detect($dir) {
    if (Test-Path (Join-Path $dir "package.json")) {
        $raw = Get-Content (Join-Path $dir "package.json") -Raw
        $cmd = "npm start"; $port = 3000
        try { $j = $raw | ConvertFrom-Json; if ($j.scripts.dev) { $cmd = "npm run dev" } elseif ($j.scripts.start) { $cmd = "npm start" } } catch { }
        if ($raw -match "vite") { $port = 5173 }
        return @{ Cmd=$cmd; Port=$port }
    }
    if (Test-Path (Join-Path $dir "manage.py")) { return @{ Cmd="python manage.py runserver"; Port=8000 } }
    foreach ($f in @("app.py","server.py","main.py","run.py")) {
        if (Test-Path (Join-Path $dir $f)) { return @{ Cmd="python $f"; Port=8000 } }
    }
    # any other python script with a __main__ entry point (e.g. bridge_glue.py)
    $pys = @(Get-ChildItem $dir -Filter *.py -File -ErrorAction SilentlyContinue |
        Where-Object { $_.BaseName -notmatch '^(setup|test|conftest|_)' })
    if ($pys.Count -gt 0) {
        $entry = $pys | Where-Object {
            (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match '__main__'
        } | Select-Object -First 1
        if (-not $entry -and $pys.Count -eq 1) { $entry = $pys[0] }
        if ($entry) {
            $port = ''
            $raw = Get-Content $entry.FullName -Raw -ErrorAction SilentlyContinue
            if ($raw -match '(?i)port["'']?\s*[=:,]\s*["'']?(\d{2,5})') { $port = $Matches[1] }
            return @{ Cmd = "python $($entry.Name)"; Port = $port }
        }
    }
    # fall back: a .bat/.cmd launch script -> add without a port
    $bats = @(Get-ChildItem $dir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -ieq '.bat' -or $_.Extension -ieq '.cmd' } |
        Where-Object { $_.BaseName -notmatch '^(launcher|install|uninstall|setup|build|test)' })
    if ($bats.Count -gt 0) {
        $pref = $bats | Where-Object { $_.BaseName -match '^(start|run|launch|serve|go)' } | Select-Object -First 1
        if (-not $pref) { $pref = $bats[0] }
        return @{ Cmd = "call `"$($pref.Name)`""; Port = '' }
    }
    return $null
}

Write-Host ""
Write-Host (C 92 "  Scanning $Root ...")

$cands = @()
# include the given folder itself as a candidate (in case it IS the project)
$dirs = @(Get-Item $Root -ErrorAction SilentlyContinue) + @(Get-ChildItem $Root -Directory -ErrorAction SilentlyContinue)
foreach ($d in $dirs) {
    $full = $d.FullName
    if ($existingDirs -contains $full.TrimEnd('\').ToLower()) { continue }
    $det = Detect $full
    if (-not $det) { continue }
    $nm = ($d.Name -replace '\s+','-').ToLower()
    $cands += [pscustomobject]@{ Name=$nm; Dir=$full; Cmd=$det.Cmd; Port=$det.Port }
}

if ($cands.Count -eq 0) {
    Write-Host (C 90 "  No new launchable projects found (Node, Django, or Python).")
    return
}

Write-Host ""
Write-Host (C 92 "  Found these projects:")
$i = 0
foreach ($c in $cands) {
    $i++
    $pdisp = if ($c.Port) { ":$($c.Port)" } else { "no port" }
    Write-Host ("    " + (C 92 "$i)") + " " + $c.Name.PadRight(20) + (C 90 ("{0}  ->  {1}  {2}" -f $c.Dir, $c.Cmd, $pdisp)))
}
Write-Host ""
$pick = Read-Host "  Add which? (e.g. 1,3  or  all  -  blank to cancel)"
if (-not $pick) { Write-Host (C 90 "  cancelled."); return }

$chosen = @()
if ($pick -ieq "all") { $chosen = 1..$cands.Count }
else { $chosen = $pick -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ } }

$added = 0
foreach ($n in $chosen) {
    if ($n -lt 1 -or $n -gt $cands.Count) { continue }
    $c = $cands[$n-1]
    Add-Content -Path $Cfg -Value ("{0}|{1}|{2}|{3}" -f $c.Name, $c.Dir, $c.Cmd, $c.Port)
    Write-Host (C 92 "  + added $($c.Name)")
    $added++
}
Write-Host ""
Write-Host (C 90 "  $added server(s) added. Review them with /list.")
