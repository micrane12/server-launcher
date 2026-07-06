# Server Launcher

A simple control panel for your local dev servers. Start, stop, and watch them
from one `server` prompt. No pm2, no extra installs — just Windows.

## Install
Open **PowerShell** and paste this one line:

```
powershell -c "irm https://raw.githubusercontent.com/micrane12/server-launcher/main/install.ps1 | iex"
```

Then open a **new** terminal and type:

```
server
```

That's it. (Run the same line again anytime to update to the latest version.)

## Add your servers
Inside the launcher, type `/add` and answer four questions:

- **name** – a label, e.g. `my-api`
- **folder** – where the project lives, e.g. `C:\Dev\MY API`
- **start command** – what you'd type to run it, e.g. `python app.py` or `npm run dev`
- **port** – the port it uses, e.g. `8000`

## Everyday use
Type `/` at the prompt to see every command. The main ones:

| Command | What it does |
|---|---|
| `/list` | show all servers and their status |
| `/status` | live auto-refreshing dashboard |
| `/start <name>` | start a server (or `/start all`) |
| `/stop <name>` | stop a server (or `/stop all`) |
| `/restart <name>` | restart a server |
| `/open <name>` | open it in your browser |
| `/logs <name>` | view its logs |
| `/add` / `/remove <name>` | add or remove a server |
| `/quit` | exit |

You can use a server's name or number with any command.
