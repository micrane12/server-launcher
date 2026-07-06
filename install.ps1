# Server Launcher installer
# One-line install:
#   powershell -c "irm https://raw.githubusercontent.com/micrane12/server-launcher/main/install.ps1 | iex"

$ErrorActionPreference = "Stop"
$repo = "https://github.com/micrane12/server-launcher.git"
$zip  = "https://github.com/micrane12/server-launcher/archive/refs/heads/main.zip"
$dest = Join-Path $env:LOCALAPPDATA "server-launcher"

Write-Host "Installing Server Launcher to $dest ..." -ForegroundColor Green

# 1) get the files (git if available, else download zip)
if (Get-Command git -ErrorAction SilentlyContinue) {
    if (Test-Path (Join-Path $dest ".git")) {
        Write-Host "  updating existing install (git pull)..."
        git -C $dest pull --quiet
    } else {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        git clone --quiet $repo $dest
    }
} else {
    Write-Host "  git not found - downloading zip..."
    $tmp = Join-Path $env:TEMP "server-launcher.zip"
    Invoke-WebRequest -Uri $zip -OutFile $tmp
    $ext = Join-Path $env:TEMP "server-launcher-extract"
    if (Test-Path $ext) { Remove-Item $ext -Recurse -Force }
    Expand-Archive -Path $tmp -DestinationPath $ext -Force
    $inner = Get-ChildItem $ext -Directory | Select-Object -First 1
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Move-Item $inner.FullName $dest
    Remove-Item $tmp -Force
}

# 2) create servers.txt from template on first install
$cfg = Join-Path $dest "servers.txt"
$tpl = Join-Path $dest "servers.example.txt"
if ((-not (Test-Path $cfg)) -and (Test-Path $tpl)) { Copy-Item $tpl $cfg }

# 3) create a "server" launcher wrapper
$wrapper = Join-Path $dest "server.cmd"
Set-Content -Encoding ASCII $wrapper @(
    "@echo off",
    "call ""%~dp0launcher.bat"" %*"
)

# 4) add the folder to the user PATH (once)
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$dest*") {
    [Environment]::SetEnvironmentVariable("PATH", "$userPath;$dest", "User")
    Write-Host "  added to PATH." -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! Open a NEW terminal and run:  server" -ForegroundColor Green
Write-Host "Then edit your servers in:  $cfg" -ForegroundColor DarkGray
