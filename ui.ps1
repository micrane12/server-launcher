param([string]$Mode = "banner")

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$TL=[char]0x256D; $TR=[char]0x256E; $BL=[char]0x2570; $BR=[char]0x256F   # rounded corners
$H =[char]0x2500; $V =[char]0x2502

# Only green is the highlight; borders/labels neutral gray.
$cyan="DarkGray"; $dim="DarkGray"; $white="White"; $orange="Green"; $green="Green"

function Box-Line($text, $w, $color=$white) {
    Write-Host $V -NoNewline -ForegroundColor $cyan
    Write-Host (" " + $text.PadRight($w - 1)) -NoNewline -ForegroundColor $color
    Write-Host $V -ForegroundColor $cyan
}

function Show-Banner {
    $w = 46
    $bar = $H.ToString() * $w
    Write-Host ("$TL$bar$TR") -ForegroundColor $cyan
    Box-Line "" $w
    Box-Line ([char]0x2726 + "  Server Launcher") $w $orange
    Box-Line "   pm2-powered control panel" $w $dim
    Box-Line "" $w
    Box-Line "Type  /  to see commands" $w $white
    Box-Line "" $w
    Write-Host ("$BL$bar$BR") -ForegroundColor $cyan
}

function Cmd-Line($cmd, $desc) {
    Write-Host ("  " + $cmd.PadRight(16)) -NoNewline -ForegroundColor $green
    Write-Host $desc -ForegroundColor $dim
}

function Show-Help {
    Write-Host ""
    Write-Host "  Commands" -ForegroundColor $orange
    Write-Host "  --------" -ForegroundColor $dim
    Cmd-Line "/list"            "live status blocks of every server"
    Cmd-Line "/watch"           "auto-refreshing status (press a key to stop)"
    Cmd-Line "/status"          "live auto-refreshing dashboard"
    Cmd-Line "/start <name|all>" "start a server (by name or number), or all"
    Cmd-Line "/stop  <name|all>" "stop a server, or all"
    Cmd-Line "/restart <name>"  "restart a server, or all"
    Cmd-Line "/open  <name>"    "open a server in the browser"
    Cmd-Line "/logs  <name>"    "tail a server's logs (Ctrl+C to stop)"
    Cmd-Line "/add"             "add a new server (guided)"
    Cmd-Line "/remove <name>"   "remove a server (by name or number)"
    Cmd-Line "/launch"          "list .bat/.cmd helpers found in project folders"
    Cmd-Line "/launch <n>"      "run one of those helpers by number"
    Cmd-Line "/help  or  /"      "show this help"
    Cmd-Line "/quit"            "exit"
    Write-Host ""
    Write-Host "  Tip: leave the number off (e.g. /start) to pick from a list." -ForegroundColor $dim
    Write-Host ""
}

switch ($Mode) {
    "help"  { Show-Help }
    default { Show-Banner }
}
