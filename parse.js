// Reads `pm2 jlist` JSON from stdin, prints a tiny TSV:
// name <tab> status <tab> cpu <tab> memoryBytes <tab> pm_uptimeMs <tab> restarts
let d = '';
process.stdin.on('data', c => d += c);
process.stdin.on('end', () => {
  try {
    const arr = JSON.parse(d);
    arr.forEach(p => {
      const e = p.pm2_env || {};
      const m = p.monit || {};
      process.stdout.write(
        [p.name, e.status || '', m.cpu || 0, m.memory || 0, e.pm_uptime || 0, e.restart_time || 0].join('\t') + '\n'
      );
    });
  } catch (err) { /* ignore */ }
});
