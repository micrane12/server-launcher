param([string]$Mode = "banner")

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$e  = [char]27
$TL=[char]0x256D; $TR=[char]0x256E; $BL=[char]0x2570; $BR=[char]0x256F   # rounded corners
$H =[char]0x2500; $V =[char]0x2502

# ---- compact 3-row title font (box-drawing style) ----
# glyph data uses ASCII placeholders, translated to box chars at runtime
$GMAP = @{
    'r' = [char]0x250C; '-' = [char]0x2500; '7' = [char]0x2510
    'L' = [char]0x2514; 'J' = [char]0x2518; 'E' = [char]0x251C
    '3' = [char]0x2524; 'T' = [char]0x252C; 'W' = [char]0x2534
    '|' = [char]0x2502
}
$FONT = @{
    'S' = @('r-7','L-7','L-J')
    'E' = @('r-7','E3 ','L-J')
    'R' = @('T-7','ETJ','WL-')
    'V' = @('T  T','L7rJ',' LJ ')
    'L' = @('T  ','|  ','W-J')
    'A' = @('r-7','E-3','W W')
    'U' = @('T T','| |','L-J')
    'N' = @('r7r','|||','JLJ')
    'C' = @('r-7','|  ','L-J')
    'H' = @('T T','E-3','W W')
    ' ' = @('  ','  ','  ')
}
function TR([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        if ($GMAP.ContainsKey("$ch")) { [void]$sb.Append($GMAP["$ch"]) } else { [void]$sb.Append($ch) }
    }
    $sb.ToString()
}
function Title-Rows([string]$text) {
    foreach ($r in 0..2) {
        $parts = foreach ($ch in $text.ToCharArray()) { $FONT["$ch"][$r] }
        TR (($parts -join ' '))
    }
}

# ---- theme: green on black ----
$GREEN = "$e[92m"
$GRAY  = "$e[90m"
$WHITE = "$e[97m"
$RST   = "$e[0m"

# Clip a colored line to the window width (ANSI codes don't count) so narrow
# windows hide the overflow instead of wrapping and breaking the layout.
function Clip([string]$s) {
    try { $max = [Console]::WindowWidth - 1 } catch { return $s }
    if ($max -lt 1) { return $s }
    $sb = New-Object System.Text.StringBuilder
    $vis = 0; $i = 0; $ch = $s.ToCharArray(); $clipped = $false
    while ($i -lt $ch.Length) {
        if ($ch[$i] -eq $e) {
            [void]$sb.Append($ch[$i]); $i++
            while ($i -lt $ch.Length) {
                $c = $ch[$i]; [void]$sb.Append($c); $i++
                if ($c -match '[A-Za-z]') { break }
            }
        } elseif ($vis -ge $max) {
            $clipped = $true; $i++
        } else {
            [void]$sb.Append($ch[$i]); $vis++; $i++
        }
    }
    if ($clipped) { [void]$sb.Append("$e[0m") }
    $sb.ToString()
}
function WL([string]$s = "") { Write-Host (Clip $s) }

try { $W = [Console]::WindowWidth } catch { $W = 80 }
if ($W -lt 40) { $W = 40 }

function CenterPad([int]$len) {
    $p = [int](($W - $len) / 2)
    if ($p -lt 0) { $p = 0 }
    return (' ' * $p)
}

function Show-Banner {
    Write-Host ""
    foreach ($row in (Title-Rows 'SERVER LAUNCHER')) {
        WL ((CenterPad $row.Length) + $GREEN + $row + $RST)
    }
    Write-Host ""

    $tag = "y o u r   l o c a l   d e v   c o n t r o l   p a n e l"
    WL ((CenterPad $tag.Length) + $GRAY + $tag + $RST)
    Write-Host ""

    $desc = "Start, stop and watch your dev servers from one terminal."
    WL ((CenterPad $desc.Length) + $WHITE + $desc + $RST)
    Write-Host ""

    $hint = "$ type /  to see all commands"
    WL ((CenterPad $hint.Length) + $GREEN + '$' + $RST + $GRAY + $hint.Substring(1) + $RST)
    Write-Host ""
}

function Cmd-Line($cmd, $desc) {
    WL ("   " + $GREEN + $cmd.PadRight(17) + $RST + $GRAY + $desc + $RST)
}

function Show-Help {
    Write-Host ""
    WL ("   " + $WHITE + "Commands" + $RST)
    WL ("   " + $GRAY + ($H.ToString() * 8) + $RST)
    Cmd-Line "/list"             "live status blocks of every server"
    Cmd-Line "/watch"            "auto-refreshing status (press a key to stop)"
    Cmd-Line "/status"           "live auto-refreshing dashboard"
    Cmd-Line "/start <name|all>" "start a server (by name or number), or all"
    Cmd-Line "/stop  <name|all>" "stop a server, or all"
    Cmd-Line "/restart <name>"   "restart a server, or all"
    Cmd-Line "/open  <name>"     "open a cmd window at the server's folder"
    Cmd-Line "/edit  <name>"     "open the server's folder in VS Code"
    Cmd-Line "/browser <name>"   "open http://localhost:<port> in your browser"
    Cmd-Line "/env   <name>"     "open the server's .env file"
    Cmd-Line "/info  <name>"     "full detail for one server (pid, uptime, paths)"
    Cmd-Line "/logs  <name>"     "tail a server's logs (Ctrl+C to stop)"
    Cmd-Line "/clear-logs <name>" "empty a server's log file"
    Cmd-Line "/add"              "add a new server (guided)"
    Cmd-Line "/scan"             "auto-detect projects in a folder and add them"
    Cmd-Line "/remove <name>"    "remove a server (by name or number)"
    Cmd-Line "/move"             "reorder servers (arrows + Enter to grab/drop)"
    Cmd-Line "/move <n> <pos>"   "move server n to position pos directly"
    Cmd-Line "/launch"           "list .bat/.cmd helpers found in project folders"
    Cmd-Line "/launch <n>"       "run one of those helpers by number"
    Cmd-Line "/home"             "clear the screen, back to the front page"
    Cmd-Line "/help  or  /"      "show this help"
    Cmd-Line "/quit"             "exit"
    Write-Host ""
    WL ("   " + $GRAY + "tip: leave the name off (e.g. /start) to pick from a list" + $RST)
    Write-Host ""
}

switch ($Mode) {
    "help"  { Show-Help }
    default { Show-Banner }
}
