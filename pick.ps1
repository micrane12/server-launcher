param([string]$File, [string]$Out, [string]$Title = "Select")

# Reads items from -File (one per line, "value|label" or just "value").
# Shows an arrow-key menu that redraws in place; writes chosen VALUE to -Out.
# Up/Down to move, Enter to choose, Esc to cancel.

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$esc = [char]27

$items = @()
foreach ($l in (Get-Content $File)) {
    if ($l -eq "") { continue }
    if ($l -eq "-") { $items += [pscustomobject]@{ Value=""; Label=""; Sep=$true }; continue }
    $i = $l.IndexOf('|')
    if ($i -ge 0) { $items += [pscustomobject]@{ Value=$l.Substring(0,$i); Label=$l.Substring($i+1) } }
    else          { $items += [pscustomobject]@{ Value=$l; Label=$l } }
}
if ($items.Count -eq 0) { return }

$sel = 0
$n = $items.Count
while ($sel -lt $n -and $items[$sel].Sep) { $sel++ }   # start on a real row
if ($sel -ge $n) { return }
[Console]::CursorVisible = $false

Write-Host ""
Write-Host ("$esc[92m  " + $Title + "$esc[0m")
Write-Host "  Up/Down to move - Enter to select - Esc to cancel" -ForegroundColor DarkGray

$first = $true
function Draw {
    if (-not $script:first) { [Console]::Write("$esc[${script:n}A") }  # move up N lines
    $script:first = $false
    for ($i = 0; $i -lt $script:n; $i++) {
        if ($script:items[$i].Sep) { [Console]::Write("$esc[2K`r`n"); continue }   # spacer row
        $mark = if ($i -eq $script:sel) { " $([char]0x25B6) " } else { "   " }
        $text = "  $mark " + $script:items[$i].Label
        if ($i -eq $script:sel) { $color = "$esc[30;42m" } else { $color = "$esc[90m" }
        # clear whole line, then write colored, padded content, then reset
        [Console]::Write("$esc[2K$color$text$esc[0m`r`n")
    }
}

try {
    while ($true) {
        Draw
        $k = [Console]::ReadKey($true)
        switch ($k.Key) {
            'UpArrow'   { $t = $sel - 1; while ($t -ge 0 -and $items[$t].Sep) { $t-- }; if ($t -ge 0) { $sel = $t } }
            'DownArrow' { $t = $sel + 1; while ($t -lt $n -and $items[$t].Sep) { $t++ }; if ($t -lt $n) { $sel = $t } }
            'Enter'     {
                if ($Out) { Set-Content -Encoding ASCII -Path $Out -Value $items[$sel].Value }
                $v = 0
                if ([int]::TryParse($items[$sel].Value, [ref]$v)) { exit (9 + $v) }   # value-based index
                exit (10 + $sel)
            }
            'Escape'    { exit 0 }
        }
    }
} finally {
    [Console]::CursorVisible = $true
    Write-Host ""
}
