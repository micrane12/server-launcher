// pm2 config for your servers
// Install pm2 once:   npm install -g pm2
// Start everything:   pm2 start ecosystem.config.js
// Check status:       pm2 list
// View logs:          pm2 logs            (or: pm2 logs remote-desktop)
// Stop one:           pm2 stop hbs-systems
// Restart one:        pm2 restart claude-bridge
// Stop everything:    pm2 stop all
// Remove everything:  pm2 delete all
// Auto-start on boot: pm2 save   (after pm2-windows-startup / pm2 startup setup)

const PYTHON = "C:/Users/kingb/AppData/Local/Programs/Python/Python314/python.exe";

module.exports = {
  apps: [
    {
      name: "remote-desktop",
      script: "server.py",
      cwd: "C:/Dev/REMOTE DESKTOP",
      interpreter: PYTHON,
      watch: false,
    },
    {
      name: "hbs-systems",
      script: "npm",
      args: "run dev",
      cwd: "C:/Dev/HOME BUILD SYSTEM/HOME BUILD SOLUTIONS",
      watch: false,
    },
    {
      name: "claude-bridge",
      script: "bridge_server.py",
      cwd: "C:/Dev/CLAUDE BRIDGE/server",
      interpreter: PYTHON,
      watch: false,
    },
  ],
};
