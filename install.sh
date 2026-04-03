#!/bin/bash
# Installation OctoNet MCP sur le serveur (a executer SUR le serveur)
# Author: Dr Hamid MADANI drmdh@msn.com
# Date: 2026-04-03
# Usage: sudo ./install.sh [APP_DIR]
#   APP_DIR: repertoire d'installation (defaut: /home/hmd/prod/octonet-mcp)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${1:-/home/hmd/prod/octonet-mcp}"
USER="${SUDO_USER:-$(whoami)}"
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  OctoNet MCP — Installation                      ${NC}"
echo -e "${CYAN}  Repertoire: ${APP_DIR}                           ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

# ── 1. Node.js ──
echo -e "\n${CYAN}[1/7] Node.js...${NC}"
if ! command -v node &>/dev/null; then
  echo -e "${YELLOW}  Installation Node.js 20 LTS...${NC}"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
echo -e "${GREEN}  Node.js $(node -v) — npm $(npm -v)${NC}"

# ── 2. PM2 ──
echo -e "\n${CYAN}[2/7] PM2...${NC}"
if ! command -v pm2 &>/dev/null; then
  npm install -g pm2
fi
echo -e "${GREEN}  PM2 $(pm2 -v)${NC}"

# ── 3. Repertoire application ──
echo -e "\n${CYAN}[3/7] Repertoire ${APP_DIR}...${NC}"
mkdir -p "${APP_DIR}/logs"
chown -R "${USER}:${USER}" "${APP_DIR}"

# Copier fichiers de config (ne pas ecraser .env si existe deja)
if [ ! -f "${APP_DIR}/.env" ]; then
  cp "${SCRIPT_DIR}/.env.production" "${APP_DIR}/.env"
  echo -e "${GREEN}  .env cree depuis .env.production${NC}"
else
  echo -e "${YELLOW}  .env existe deja — non ecrase${NC}"
fi
cp "${SCRIPT_DIR}/ecosystem.config.cjs" "${APP_DIR}/ecosystem.config.cjs"
cp "${SCRIPT_DIR}/schemas.json" "${APP_DIR}/schemas.json" 2>/dev/null || true

# ── 4. Dependances npm ──
echo -e "\n${CYAN}[4/7] Dependances npm...${NC}"
cd "${APP_DIR}"
if [ ! -f package.json ]; then
  sudo -u "${USER}" npm init -y > /dev/null 2>&1
fi
sudo -u "${USER}" npm install @mostajs/net @mostajs/orm @mostajs/mproject better-sqlite3

# ── 5. PM2 ──
echo -e "\n${CYAN}[5/7] Demarrage PM2...${NC}"
sudo -u "${USER}" pm2 delete octonet-mcp 2>/dev/null || true
sudo -u "${USER}" pm2 start "${APP_DIR}/ecosystem.config.cjs"
sudo -u "${USER}" pm2 save

# ── 6. PM2 startup ──
echo -e "\n${CYAN}[6/7] PM2 startup systemd...${NC}"
env PATH="$PATH:/usr/bin" "$(which pm2)" startup systemd -u "${USER}" --hp "/home/${USER}" 2>/dev/null || true

# ── 7. Apache ──
echo -e "\n${CYAN}[7/7] Apache...${NC}"
VHOST_FILE="/etc/apache2/sites-available/mcp.amia.fr.conf"
if [ -f "${SCRIPT_DIR}/apache/mcp.amia.fr.conf" ]; then
  cp "${SCRIPT_DIR}/apache/mcp.amia.fr.conf" "${VHOST_FILE}"
  a2enmod proxy proxy_http proxy_wstunnel ssl headers rewrite 2>/dev/null || true
  a2ensite mcp.amia.fr.conf 2>/dev/null || true
  # Retirer ServerAlias mcp.amia.fr du vhost amia.fr si present
  sed -i '/ServerAlias mcp.amia.fr/d' /etc/apache2/sites-enabled/amia.fr-le-ssl.conf 2>/dev/null || true
  apache2ctl configtest && systemctl reload apache2
  echo -e "${GREEN}  Apache configure et recharge${NC}"
else
  echo -e "${YELLOW}  Fichier apache/mcp.amia.fr.conf non trouve — Apache non configure${NC}"
fi

# ── Verification ──
echo -e "\n${CYAN}Verification...${NC}"
sleep 3
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:14500/health | grep -q "200"; then
  echo -e "${GREEN}  ✅ Serveur repond sur :14500${NC}"
else
  echo -e "${RED}  ❌ Serveur ne repond pas — verifiez: pm2 logs octonet-mcp${NC}"
fi

echo -e "\n${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation terminee !                          ${NC}"
echo -e "${GREEN}  Dashboard: https://mcp.amia.fr/                  ${NC}"
echo -e "${GREEN}  MCP:       https://mcp.amia.fr/mcp               ${NC}"
echo -e "${GREEN}  Logs:      pm2 logs octonet-mcp                   ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
