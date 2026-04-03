#!/bin/bash
# Mise a jour rapide OctoNet MCP (npm update + PM2 restart)
# A executer SUR le serveur ou via: ssh amia '/home/hmd/prod/octonet-mcp/update.sh'
# Author: Dr Hamid MADANI drmdh@msn.com
# Date: 2026-04-03
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${CYAN}OctoNet MCP — Mise a jour${NC}"

# Versions avant
OLD_VER=$(node -e "try{console.log(require('${APP_DIR}/node_modules/@mostajs/net/package.json').version)}catch(e){console.log('?')}" 2>/dev/null)

# Mise a jour npm
echo -e "${CYAN}npm update...${NC}"
cd "${APP_DIR}"
npm update @mostajs/net @mostajs/orm @mostajs/mproject 2>&1 | tail -3

# Version apres
NEW_VER=$(node -e "try{console.log(require('${APP_DIR}/node_modules/@mostajs/net/package.json').version)}catch(e){console.log('?')}" 2>/dev/null)

if [ "${OLD_VER}" = "${NEW_VER}" ]; then
  echo -e "${YELLOW}Pas de changement (v${NEW_VER})${NC}"
else
  echo -e "${GREEN}Mise a jour: v${OLD_VER} → v${NEW_VER}${NC}"
fi

# Restart PM2
echo -e "${CYAN}PM2 restart...${NC}"
pm2 restart octonet-mcp --update-env 2>&1 | grep -E "online|error"

# Verification
sleep 2
CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:14500/health 2>/dev/null || echo "000")
if [ "${CODE}" = "200" ]; then
  echo -e "${GREEN}✅ OK — @mostajs/net v${NEW_VER}${NC}"
else
  echo -e "\033[0;31m❌ Serveur ne repond pas (HTTP ${CODE})${NC}"
  echo -e "Logs: pm2 logs octonet-mcp"
fi
