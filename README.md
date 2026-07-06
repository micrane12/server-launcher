# Server Launcher

A self-contained control panel for local dev servers, driven by slash commands
from a `server` prompt in cmd. No pm2, no external dependencies — just Windows
PowerShell (built in).

## Quick install (one line)
Paste this into PowerShell:
```
powershell -c "irm https://raw.githubusercontent.com/micrane12/server-launcher/main/install.ps1 | iex"
```
It downloads the launcher, sets up `servers.txt`, and adds `server` to your PATH.
Open a **new** terminal and run `server`. Re-run the same line anytime to update.

## Files
- `launcher.bat` — the `server` prompt; routes `/list`, `/status`, `/start`, etc.
- `manager.ps1` — starts/stops/restarts servers and tails logs.
- `status.ps1` — the live status dashboard (reads each server's port).
- `ui.ps1` — banner + help screens.
- `servers.txt` — **the only file you edit per machine.**

## servers.txt format
One server per line, no spaces around the `|`:
```
name|working folder|start command|port
remote-desktop|C:\Dev\REMOTE DESKTOP|python server.py|5000
```
Lines starting with `#` are ignored.

## Setup on a new machine
1. Clone the repo:
   ```
   git clone https://github.com/<your-username>/server-launcher.git "C:\Dev\SERVER LAUNCHER"
   ```
2. First run creates `servers.txt` from `servers.example.txt` automatically.
   Edit **servers.txt** to match this machine's folders, commands, and ports.
   (Your `servers.txt` is git-ignored, so each machine keeps its own.)
3. (Optional) add the folder to PATH so you can type `server` anywhere:
   ```
   powershell -Command "[Environment]::SetEnvironmentVariable('PATH', [Environment]::GetEnvironmentVariable('PATH','User') + ';C:\Dev\SERVER LAUNCHER', 'User')"
   ```
   Open a new cmd window, then run `server`.

## Pushing changes (first time)
Create an empty repo on GitHub (no README), then from this folder:
```
git init
git add .
git commit -m "Server launcher"
git branch -M main
git remote add origin https://github.com/<your-username>/server-launcher.git
git push -u origin main
```
After that, `git add . && git commit -m "..." && git push` to update it.

## Commands
Type `/` at the `server>` prompt to see them all: `/list`, `/status`, `/watch`,
`/start`, `/stop`, `/restart`, `/open`, `/logs`, `/add`, `/remove`, `/launch`, `/quit`.

Use a number (`/start 2`) or `all` (`/start all`); leave it off to pick from a list.

### Adding servers
Use `/add` inside the launcher — it asks for four things:
- **name** – a short label for the dashboard (e.g. `my-api`)
- **folder path** – full path to the project (e.g. `C:\Dev\MY API`)
- **start command** – what you'd type to run it from that folder (e.g. `python app.py`, `npm run dev`)
- **port** – the localhost port it listens on (e.g. `8000`)

`/remove <n>` deletes one. Both write to `servers.txt` and reload immediately.

### /launch
`/launch` lists any `.bat`/`.cmd` helper files found in your project folders,
grouped by server. `/launch <n>` runs one.

## How it works
Each server is launched hidden with its output logged to `logs\<name>.log`.
Status is detected by checking which process is listening on each server's port,
so servers started any other way still show up. Runtime state lives in `.pids\`
and `logs\` (both git-ignored).
