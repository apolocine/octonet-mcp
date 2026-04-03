// PM2 Ecosystem — OctoNet MCP
// Author: Dr Hamid MADANI drmdh@msn.com
const { readFileSync } = require('fs');
const { resolve } = require('path');
const envFile = resolve(__dirname, '.env');
const envVars = {};
try {
  const lines = readFileSync(envFile, 'utf8').split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const [key, ...rest] = trimmed.split('=');
    envVars[key.trim()] = rest.join('=').trim();
  }
} catch(e) {}
module.exports = {
  apps: [{
    name: 'octonet-mcp',
    script: 'node_modules/.bin/mostajs-net',
    args: 'serve',
    cwd: __dirname,
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    error_file: resolve(__dirname, 'logs/error.log'),
    out_file: resolve(__dirname, 'logs/out.log'),
    merge_logs: true,
    env: {
      NODE_ENV: 'production',
      ...envVars,
    },
  }],
};
