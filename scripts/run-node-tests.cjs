const { spawnSync } = require('node:child_process');

// Node 22 exposes isolation under its experimental name; Node 24 stabilizes it.
// Running in-process also works in restricted Windows development environments.
const help = spawnSync(process.execPath, ['--help'], { encoding: 'utf8' });
if (help.status !== 0) process.exit(help.status ?? 1);
const isolation = help.stdout.includes('--test-isolation=')
  ? '--test-isolation=none'
  : help.stdout.includes('--experimental-test-isolation=')
    ? '--experimental-test-isolation=none'
    : null;
const args = ['--test', ...(isolation ? [isolation] : []), ...process.argv.slice(2)];
const result = spawnSync(process.execPath, args, { stdio: 'inherit' });
if (result.error) console.error(result.error.message);
process.exit(result.status ?? 1);
