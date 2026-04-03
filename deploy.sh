#!/bin/bash
# Deployer OctoNet MCP depuis le poste local vers amia.fr
# Author: Dr Hamid MADANI drmdh@msn.com
# Date: 2026-04-03
# Usage: ./deploy.sh [ssh-alias] [remote-dir]
#   ssh-alias:  alias SSH (defaut: amia)
#   remote-dir: repertoire distant (defaut: /home/hmd/prod/octonet-mcp)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_HOST="${1:-amia}"
REMOTE_DIR="${2:-/home/hmd/prod/octonet-mcp}"
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  OctoNet MCP — Deploiement vers ${SSH_HOST}       ${NC}"
echo -e "${CYAN}  Remote: ${REMOTE_DIR}                            ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

# ── 1. Creer le repertoire distant ──
echo -e "\n${CYAN}[1/5] Preparation repertoire distant...${NC}"
ssh "${SSH_HOST}" "mkdir -p ${REMOTE_DIR}/logs"

# ── 2. Copier les fichiers ──
echo -e "\n${CYAN}[2/5] Copie des fichiers...${NC}"
# Fichiers de config (toujours)
scp "${SCRIPT_DIR}/ecosystem.config.cjs" "${SSH_HOST}:${REMOTE_DIR}/"
scp "${SCRIPT_DIR}/schemas.json" "${SSH_HOST}:${REMOTE_DIR}/"
scp -r "${SCRIPT_DIR}/apache" "${SSH_HOST}:${REMOTE_DIR}/"
scp "${SCRIPT_DIR}/install.sh" "${SSH_HOST}:${REMOTE_DIR}/"
scp "${SCRIPT_DIR}/update.sh" "${SSH_HOST}:${REMOTE_DIR}/"
# .env seulement si absent sur le serveur
ssh "${SSH_HOST}" "test -f ${REMOTE_DIR}/.env || echo 'NEED_ENV'"
NEED_ENV=$(ssh "${SSH_HOST}" "test -f ${REMOTE_DIR}/.env && echo NO || echo YES")
if [ "${NEED_ENV}" = "YES" ]; then
  scp "${SCRIPT_DIR}/.env.production" "${SSH_HOST}:${REMOTE_DIR}/.env"
  echo -e "${GREEN}  .env deploye (premier deploiement)${NC}"
else
  echo -e "${YELLOW}  .env distant conserve (existe deja)${NC}"
fi
echo -e "${GREEN}  Fichiers copies${NC}"

# ── 3. Installer/mettre a jour npm ──
echo -e "\n${CYAN}[3/5] Installation npm sur le serveur...${NC}"
ssh "${SSH_HOST}" "cd ${REMOTE_DIR} && (test -f package.json || npm init -y > /dev/null 2>&1) && npm install @mostajs/net @mostajs/orm @mostajs/mproject better-sqlite3 2>&1" | tail -5
echo -e "${GREEN}  Packages npm installes${NC}"

# ── 4. Redemarrer PM2 ──
echo -e "\n${CYAN}[4/5] Redemarrage PM2...${NC}"
ssh "${SSH_HOST}" "cd ${REMOTE_DIR} && pm2 delete octonet-mcp 2>/dev/null; pm2 start ecosystem.config.cjs && pm2 save" 2>&1 | grep -E "online|error|launched"
echo -e "${GREEN}  PM2 redemarre${NC}"

# ── 5. Verification ──
echo -e "\n${CYAN}[5/5] Verification...${NC}"
sleep 3
HTTP_CODE=$(ssh "${SSH_HOST}" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:14500/health" 2>/dev/null || echo "000")
if [ "${HTTP_CODE}" = "200" ]; then
  echo -e "${GREEN}  ✅ Serveur OK (HTTP ${HTTP_CODE})${NC}"
  # Test MCP
  MCP_CODE=$(ssh "${SSH_HOST}" "curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:14500/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{\"jsonrpc\":\"2.0\",\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"deploy-test\",\"version\":\"1.0\"}},\"id\":1}'" 2>/dev/null || echo "000")
  if [ "${MCP_CODE}" = "200" ]; then
    echo -e "${GREEN}  ✅ MCP endpoint OK${NC}"
  else
    echo -e "${YELLOW}  ⚠️  MCP endpoint HTTP ${MCP_CODE}${NC}"
  fi
else
  echo -e "${RED}  ❌ Serveur ne repond pas (HTTP ${HTTP_CODE})${NC}"
  echo -e "${RED}  Verifiez: ssh ${SSH_HOST} 'pm2 logs octonet-mcp'${NC}"
fi

# Versions
VERSIONS=$(ssh "${SSH_HOST}" "cd ${REMOTE_DIR} && node -e \"const p=require('./node_modules/@mostajs/net/package.json'); console.log('net:'+p.version)\" 2>/dev/null" || echo "?")
echo -e "\n${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deploiement termine !  ${VERSIONS}                ${NC}"
echo -e "${GREEN}  Dashboard: https://mcp.amia.fr/                  ${NC}"
echo -e "${GREEN}  MCP:       https://mcp.amia.fr/mcp               ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
