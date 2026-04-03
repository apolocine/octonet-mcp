#!/bin/bash
# Deploiement OctoNet MCP sur mcp.amia.fr
# Author: Dr Hamid MADANI drmdh@msn.com
# Date: 2026-04-03
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

echo -e "${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  OctoNet MCP — Deploiement mcp.amia.fr           ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════${NC}"

# ── 1. Node.js ──
echo -e "\n${CYAN}[1/6] Verification Node.js...${NC}"
if ! command -v node &>/dev/null; then
  echo -e "${YELLOW}  Node.js non installe. Installation via NodeSource...${NC}"
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
echo -e "${GREEN}  Node.js $(node -v) — npm $(npm -v)${NC}"

# ── 2. PM2 ──
echo -e "\n${CYAN}[2/6] Installation PM2...${NC}"
if ! command -v pm2 &>/dev/null; then
  sudo npm install -g pm2
  pm2 startup systemd -u "$(whoami)" --hp "$HOME" | tail -1 | bash || true
fi
echo -e "${GREEN}  PM2 $(pm2 -v)${NC}"

# ── 3. Repertoire application ──
APP_DIR="/opt/octonet-mcp"
echo -e "\n${CYAN}[3/6] Preparation $APP_DIR...${NC}"
sudo mkdir -p "$APP_DIR"
sudo chown "$(whoami):$(whoami)" "$APP_DIR"

# Copier les fichiers
cp "$(dirname "$0")/.env.production" "$APP_DIR/.env"
cp "$(dirname "$0")/ecosystem.config.cjs" "$APP_DIR/ecosystem.config.cjs"
cp "$(dirname "$0")/schemas.json" "$APP_DIR/schemas.json" 2>/dev/null || true

cd "$APP_DIR"

# Installer le package
echo -e "\n${CYAN}[4/6] Installation @mostajs/net...${NC}"
npm init -y > /dev/null 2>&1
npm install @mostajs/net @mostajs/orm @mostajs/mproject

# ── 5. Demarrer avec PM2 ──
echo -e "\n${CYAN}[5/6] Demarrage PM2...${NC}"
pm2 delete octonet-mcp 2>/dev/null || true
pm2 start ecosystem.config.cjs
pm2 save

# ── 6. Apache VirtualHost ──
echo -e "\n${CYAN}[6/6] Configuration Apache...${NC}"
VHOST_FILE="/etc/apache2/sites-available/mcp.amia.fr.conf"
if [ ! -f "$VHOST_FILE" ]; then
  sudo cp "$(dirname "$0")/apache-mcp.amia.fr.conf" "$VHOST_FILE"
  sudo a2enmod proxy proxy_http proxy_wstunnel ssl headers rewrite
  sudo a2ensite mcp.amia.fr.conf
  echo -e "${YELLOW}  VirtualHost copie. Editez $VHOST_FILE pour ajuster le certificat SSL.${NC}"
  echo -e "${YELLOW}  Puis: sudo systemctl reload apache2${NC}"
else
  echo -e "${GREEN}  VirtualHost deja present.${NC}"
fi

echo -e "\n${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deploiement termine !                            ${NC}"
echo -e "${GREEN}  Verifiez: curl https://mcp.amia.fr/mcp           ${NC}"
echo -e "${GREEN}  PM2 logs: pm2 logs octonet-mcp                   ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
