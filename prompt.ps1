param([string]$Out, [int]$Front = 0)

# Interactive input line for launcher.bat.
# Type "/" -> live command hints (max 5). Tab = autocomplete, Up/Down = choose,
# Enter = submit (accepts highlighted hint if you navigated), Esc = clear line.
# Writes the final line to -Out.

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$esc = [char]27
$keyLog = Join-Path $PSScriptRoot 'keys.log'

$commands = @(
    [pscustomobject]@{ C='/list';    D='live status blocks of every server' }
    [pscustomobject]@{ C='/status';  D='live auto-refreshing dashboard' }
    [pscustomobject]@{ C='/watch';   D='auto-refreshing status' }
    [pscustomobject]@{ C='/start';   D='start a server (name/number/all)' }
    [pscustomobject]@{ C='/stop';    D='stop a server, or all' }
    [pscustomobject]@{ C='/restart'; D='restart a server, or all' }
    [pscustomobject]@{ C='/open';    D='open a cmd window at the server folder' }
    [pscustomobject]@{ C='/logs';    D='tail a server''s logs' }
    [pscustomobject]@{ C='/add';     D='add a new server (guided)' }
    [pscustomobject]@{ C='/scan';    D='auto-detect projects in a folder' }
    [pscustomobject]@{ C='/remove';  D='remove a server' }
    [pscustomobject]@{ C='/move';    D='reorder servers (grab and drop)' }
    [pscustomobject]@{ C='/launch';  D='run a .bat/.cmd helper script' }
    [pscustomobject]@{ C='/home';    D='clear screen, back to the front page' }
    [pscustomobject]@{ C='/help';    D='show all commands' }
    [pscustomobject]@{ C='/quit';    D='exit' }
)

$promptText = 'server > '
$buffer = ''
$sel = 0
$navigated = $false
$tabBase = $null   # the filter text captured on first Tab; non-null while cycling
$winTop = 0        # first visible row of the suggestion window

function Get-Suggestions([string]$buf) {
    if ($buf.Length -eq 0 -or $buf[0] -ne '/' -or $buf.Contains(' ')) { return @() }
    if ($buf -eq '/') { return @($commands) }
    return @($commands | Where-Object { $_.C.StartsWith($buf, 'OrdinalIgnoreCase') })
}

function Render([object[]]$sugs) {
    [Console]::Write("`r$esc[J")
    [Console]::Write("$esc[92m$promptText$esc[0m$script:buffer")
    if ($sugs.Count -gt 0) {
        # scrolling 5-row window that follows the selection
        $maxRows = 5
        if ($script:sel -lt $script:winTop) { $script:winTop = $script:sel }
        if ($script:sel -gt $script:winTop + $maxRows - 1) { $script:winTop = $script:sel - $maxRows + 1 }
        $maxTop = [Math]::Max(0, $sugs.Count - $maxRows)
        if ($script:winTop -gt $maxTop) { $script:winTop = $maxTop }
        $last = [Math]::Min($script:winTop + $maxRows - 1, $sugs.Count - 1)
        $rows = 0
        for ($i = $script:winTop; $i -le $last; $i++) {
            $line = "   " + $sugs[$i].C.PadRight(10) + "  " + $sugs[$i].D
            if ($i -eq $script:sel) { [Console]::Write("`r`n$esc[2K$esc[30;42m$line$esc[0m") }
            else                    { [Console]::Write("`r`n$esc[2K$esc[90m$line$esc[0m") }
            $rows++
        }
        if ($sugs.Count -gt $maxRows) {
            [Console]::Write("`r`n$esc[2K$esc[90m   $($script:sel + 1)/$($sugs.Count)  (Tab or arrows for more)$esc[0m")
            $rows++
        }
        # cursor back up to the input line, at end of the buffer
        [Console]::Write("$esc[$($rows)A")
        [Console]::Write("$esc[$($promptText.Length + $script:buffer.Length + 1)G")
    }
}

$lastW = 0
try { $lastW = [Console]::WindowWidth } catch { }

while ($true) {
    $filter = if ($null -ne $tabBase) { $tabBase } else { $buffer }
    $sugs = @(Get-Suggestions $filter)   # @() so a single match stays an array
    if ($sel -ge $sugs.Count) { $sel = 0 }
    Render $sugs
    # wait for a key; meanwhile watch for terminal resize
    while (-not [Console]::KeyAvailable) {
        Start-Sleep -Milliseconds 100
        $w = $lastW
        try { $w = [Console]::WindowWidth } catch { }
        if ($w -ne $lastW) {
            # wait until the size settles (user done dragging)
            do {
                $lastW = $w
                Start-Sleep -Milliseconds 250
                try { $w = [Console]::WindowWidth } catch { }
            } while ($w -ne $lastW)
            if ($Front -eq 1 -and $buffer -eq '') {
                # on the front page with nothing typed: ask launcher.bat for a full redraw
                if ($Out) { Set-Content -Encoding ASCII -Path $Out -Value '__redraw__' }
                [Console]::Write("`r$esc[J")
                return
            }
            Render $sugs
        }
    }
    $k = [Console]::ReadKey($true)
    $kc = [int]$k.KeyChar
    $kk = $k.Key
    try { Add-Content -Path $keyLog -Value ("{0:HH:mm:ss.fff}  key={1} char={2} mod={3} buf='{4}' tb='{5}' sel={6} sugs={7}" -f (Get-Date), $kk, $kc, $k.Modifiers, $buffer, $tabBase, $sel, $sugs.Count) } catch { }

    try {
        if ($kc -eq 13 -or $kk -eq [ConsoleKey]::Enter) {
            # accept the highlighted suggestion (except bare "/", which opens help)
            if ($buffer -ne '/' -and $sugs.Count -gt 0) { $buffer = $sugs[$sel].C }
            [Console]::Write("`r$esc[J")
            [Console]::Write("$esc[92m$promptText$esc[0m$buffer`r`n")
            if ($Out) { Set-Content -Encoding ASCII -Path $Out -Value $buffer }
            return
        }
        elseif ($kc -eq 9 -or $kk -eq [ConsoleKey]::Tab) {
            if ($sugs.Count -gt 0) {
                # complete straight from the hint list on screen
                if ([string]::IsNullOrEmpty($tabBase)) {
                    $tabBase = $filter                    # first tab
                    if (-not $navigated) { $sel = 0 }     # -> first option
                } else {
                    $sel = ($sel + 1) % $sugs.Count       # further tabs -> cycle
                }
                $buffer = $sugs[$sel].C + ' '
            }
            elseif ($buffer.TrimEnd() -eq '') {
                # tab on an empty line -> first command
                $all = @(Get-Suggestions '/')
                if ($all.Count -gt 0) { $tabBase = '/'; $sel = 0; $buffer = $all[0].C + ' ' }
            }
            $navigated = $false
        }
        elseif ($kk -eq [ConsoleKey]::UpArrow) {
            if ($sugs.Count -gt 0) { $sel = ($sel - 1 + $sugs.Count) % $sugs.Count; $navigated = $true }
        }
        elseif ($kk -eq [ConsoleKey]::DownArrow) {
            if ($sugs.Count -gt 0) { $sel = ($sel + 1) % $sugs.Count; $navigated = $true }
        }
        elseif ($kc -eq 8 -or $kk -eq [ConsoleKey]::Backspace) {
            if ($buffer.Length -gt 0) { $buffer = $buffer.Substring(0, $buffer.Length - 1) }
            $sel = 0; $navigated = $false; $tabBase = $null
        }
        elseif ($kc -eq 27 -or $kk -eq [ConsoleKey]::Escape) {
            $buffer = ''; $sel = 0; $navigated = $false; $tabBase = $null
        }
        elseif ($k.KeyChar -and -not [char]::IsControl($k.KeyChar)) {
            $buffer += $k.KeyChar
            $sel = 0; $navigated = $false; $tabBase = $null
        }
    } catch {
        try { Add-Content -Path $keyLog -Value ("ERROR: " + $_.Exception.Message) } catch { }
    }
}
