# Server Launcher

A simple pm2-powered control panel for local dev servers, driven by slash commands
from a `server` prompt in cmd.

## Files
- `launcher.bat` — the command prompt (`server`), routes `/list`, `/status`, `/start`, etc.
- `status.ps1` — renders the live status dashboard (reads pm2 + probes ports).
- `parse.js` — trims `pm2 jlist` JSON to a tiny table for the dashboard.
- `ui.ps1` — banner + help screens.
- `ecosystem.config.js` — pm2 definitions for each server.

## Setup on a new machine
1. Install Node.js, then pm2:  `npm install -g pm2`
2. Clone this repo somewhere, e.g. `C:\Dev\SERVER LAUNCHER`.
3. Edit **two** places to match the new machine's paths:
   - `ecosystem.config.js` — each app's `cwd` / `script`.
   - `launcher.bat` — the server config block (`name#`, `port#`, `dir#`).
4. (Optional) add the folder to PATH so you can type `server` anywhere:
   ```
   powershell -Command "[Environment]::SetEnvironmentVariable('PATH', [Environment]::GetEnvironmentVariable('PATH','User') + ';C:\Dev\SERVER LAUNCHER', 'User')"
   ```
   Then open a new cmd window and run `server`.

## Commands
Type `/` at the `server>` prompt to see them all.
