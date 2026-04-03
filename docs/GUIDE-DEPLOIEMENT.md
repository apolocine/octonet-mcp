# OctoNet MCP — Guide complet de deploiement et publication
// Author: Dr Hamid MADANI drmdh@msn.com
// Date: 2026-04-03

---

## Table des matieres

1. [Vue d'ensemble](#1-vue-densemble)
2. [Architecture](#2-architecture)
3. [Prerequis serveur](#3-prerequis-serveur)
4. [Installation pas a pas](#4-installation-pas-a-pas)
5. [Configuration detaillee](#5-configuration-detaillee)
6. [Apache2 — Reverse proxy SSL](#6-apache2--reverse-proxy-ssl)
7. [PM2 — Gestion du processus](#7-pm2--gestion-du-processus)
8. [Publication sur les annuaires MCP](#8-publication-sur-les-annuaires-mcp)
9. [Depot GitHub octonet-mcp](#9-depot-github-octonet-mcp)
10. [Verification et tests](#10-verification-et-tests)
11. [Maintenance et mise a jour](#11-maintenance-et-mise-a-jour)
12. [Problemes rencontres et solutions](#12-problemes-rencontres-et-solutions)
13. [Reference des fichiers](#13-reference-des-fichiers)

---

## 1. Vue d'ensemble

OctoNet MCP est un serveur MCP (Model Context Protocol) multi-bases de donnees deploye sur `mcp.amia.fr`. Il permet aux agents IA (Claude, GPT, etc.) d'interagir avec 13 types de bases de donnees via une seule commande `npx`.

### Composants

| Composant | Role | Version |
|---|---|---|
| `@mostajs/net` | Serveur multi-transport (11 protocoles) | 2.0.45 |
| `@mostajs/orm` | ORM multi-dialecte (13 bases) | 1.7.12 |
| `@mostajs/mproject` | Gestion multi-projets | 1.0.7 |
| PM2 | Process manager (autorestart, logs) | 6.0.14 |
| Apache2 | Reverse proxy SSL | 2.4.52 |

### URLs de production

| Endpoint | URL |
|---|---|
| MCP (agents IA) | `https://mcp.amia.fr/mcp` |
| Dashboard IHM | `https://mcp.amia.fr/` |
| REST API | `https://mcp.amia.fr/api/v1/` |
| GraphQL | `https://mcp.amia.fr/graphql` |
| WebSocket | `wss://mcp.amia.fr/ws` |
| SSE | `https://mcp.amia.fr/events` |
| JSON-RPC | `https://mcp.amia.fr/rpc` |
| tRPC | `https://mcp.amia.fr/trpc/` |
| OData | `https://mcp.amia.fr/odata/` |

### Annuaires de publication

| Plateforme | Identifiant | URL |
|---|---|---|
| npm | `@mostajs/net` | https://www.npmjs.com/package/@mostajs/net |
| Registre officiel MCP | `io.github.apolocine/mosta-net` | registry.modelcontextprotocol.io |
| Smithery.ai | `mostajs/octonet-mcp` | https://smithery.ai/servers/mostajs/octonet-mcp |
| GitHub (net) | `apolocine/mosta-net` | https://github.com/apolocine/mosta-net |
| GitHub (deploy) | `apolocine/octonet-mcp` | https://github.com/apolocine/octonet-mcp |

---

## 2. Architecture

```
Internet
   |
   v
[DNS mcp.amia.fr] → [Serveur amia.fr (Ubuntu 22.04)]
                          |
                     [Apache2 :443]
                     SSL Let's Encrypt
                     Reverse Proxy
                          |
                     [OctoNet :14500]
                     PM2 (fork mode)
                          |
                 ┌────────┼────────┐
                 |        |        |
              [REST]  [GraphQL]  [MCP]  ... (8 transports)
                 |        |        |
              [@mostajs/orm]
                 |
              [SQLite :memory:]
              (demo — remplacable par
               PostgreSQL, MongoDB, etc.)
```

### Flux MCP (agents IA)

```
Claude Desktop / Smithery
        |
   POST https://mcp.amia.fr/mcp
   Content-Type: application/json
   Accept: application/json, text/event-stream
        |
   [Apache2 SSL] → [OctoNet McpTransport]
        |                    |
   initialize         tools/list → 45 tools
        |                    |
   tools/call          ORM query
        |                    |
   SSE response        JSON result
```

---

## 3. Prerequis serveur

### Serveur
- Ubuntu 22.04 LTS (ou compatible)
- Apache2 installe et actif
- Certificat SSL Let's Encrypt (couvrant `mcp.amia.fr`)
- Acces SSH avec cle (alias `amia` configure localement)
- Port 443 ouvert (HTTPS)

### Logiciels a installer

```bash
# Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# PM2 (global)
sudo npm install -g pm2

# Modules Apache necessaires
sudo a2enmod proxy proxy_http proxy_wstunnel ssl headers rewrite
```

### Verification

```bash
node -v       # v20.x
npm -v        # 11.x
pm2 -v        # 6.x
apache2 -v    # 2.4.x
```

---

## 4. Installation pas a pas

### 4.1 Creer le repertoire de production

```bash
ssh amia
mkdir -p /home/hmd/prod/octonet-mcp
cd /home/hmd/prod/octonet-mcp
```

### 4.2 Copier les fichiers depuis le poste local

```bash
# Depuis le poste de developpement
scp -r Entreprise/octonet-mcp/* amia:/home/hmd/prod/octonet-mcp/
scp Entreprise/octonet-mcp/.env.production amia:/home/hmd/prod/octonet-mcp/.env
```

### 4.3 Installer les dependances npm

```bash
ssh amia "cd /home/hmd/prod/octonet-mcp && npm init -y && npm install @mostajs/net @mostajs/orm @mostajs/mproject"
```

### 4.4 Creer le repertoire de logs

```bash
ssh amia "mkdir -p /home/hmd/prod/octonet-mcp/logs"
```

### 4.5 Demarrer avec PM2

```bash
ssh amia "cd /home/hmd/prod/octonet-mcp && pm2 start ecosystem.config.cjs && pm2 save"
```

### 4.6 Configurer le demarrage automatique

```bash
# Sur le serveur (necessite sudo)
ssh -t amia "pm2 startup systemd -u hmd --hp /home/hmd"
# Copier et executer la commande sudo affichee
ssh -t amia "sudo env PATH=\$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u hmd --hp /home/hmd"
```

### 4.7 Configurer Apache

```bash
# Copier le VirtualHost
ssh -t amia "sudo cp /home/hmd/prod/octonet-mcp/apache/mcp.amia.fr.conf /etc/apache2/sites-available/"

# Activer le site
ssh -t amia "sudo a2ensite mcp.amia.fr.conf"

# Si mcp.amia.fr est reference dans un autre VirtualHost, le retirer
ssh -t amia "sudo sed -i '/ServerAlias mcp.amia.fr/d' /etc/apache2/sites-enabled/amia.fr-le-ssl.conf"

# Verifier et recharger
ssh -t amia "sudo apache2ctl configtest && sudo systemctl reload apache2"
```

### 4.8 Script d'installation automatique

Alternativement, le script `install.sh` automatise les etapes 4.1 a 4.7 :

```bash
ssh -t amia "cd /home/hmd/prod/octonet-mcp && chmod +x install.sh && sudo ./install.sh"
```

---

## 5. Configuration detaillee

### 5.1 Fichier .env

Le fichier `.env` (copie de `.env.production`) controle le comportement du serveur :

```bash
# Base de donnees
DB_DIALECT=sqlite              # Dialecte : sqlite, postgres, mysql, mongodb, oracle, mssql, ...
SGBD_URI=:memory:              # URI de connexion (":memory:" pour SQLite en RAM)
DB_SCHEMA_STRATEGY=create      # create | update | validate | create-drop
DB_SHOW_SQL=false              # Afficher les requetes SQL dans les logs

# Serveur
MOSTA_NET_PORT=14500           # Port interne (Apache reverse proxy → ce port)

# Transports (true/false pour chaque)
MOSTA_NET_REST_ENABLED=true
MOSTA_NET_GRAPHQL_ENABLED=true
MOSTA_NET_WS_ENABLED=true
MOSTA_NET_SSE_ENABLED=true
MOSTA_NET_JSONRPC_ENABLED=true
MOSTA_NET_MCP_ENABLED=true     # OBLIGATOIRE pour le MCP
MOSTA_NET_TRPC_ENABLED=true
MOSTA_NET_ODATA_ENABLED=true
MOSTA_NET_GRPC_ENABLED=false   # Necessite port dedie (:50051)
MOSTA_NET_NATS_ENABLED=false   # Necessite nats-server
MOSTA_NET_ARROW_ENABLED=false  # Arrow Flight

# CORS
MOSTA_NET_CORS_ORIGIN=*        # Ou liste : https://smithery.ai,https://claude.ai
```

### 5.2 Schemas (schemas.json)

Les schemas definissent les entites exposees par le serveur. Chaque entite genere 15 tools MCP + routes REST/GraphQL/etc.

```json
[
  {
    "name": "User",
    "collection": "users",
    "fields": {
      "email": { "type": "string", "required": true },
      "name": { "type": "string", "required": true },
      "age": { "type": "number", "default": 0 },
      "active": { "type": "boolean", "default": true }
    },
    "relations": {},
    "indexes": []
  }
]
```

Types de champs supportes : `string`, `text`, `number`, `boolean`, `date`, `json`, `array`.

### 5.3 Changer de base de donnees

Pour passer de SQLite demo a PostgreSQL production :

```bash
# .env
DB_DIALECT=postgres
SGBD_URI=postgresql://user:pass@localhost:5432/mydb
DB_SCHEMA_STRATEGY=update
```

Puis redemarrer : `pm2 restart octonet-mcp --update-env`

---

## 6. Apache2 — Reverse proxy SSL

### 6.1 VirtualHost mcp.amia.fr.conf

Le fichier `apache/mcp.amia.fr.conf` configure :

- **HTTP → HTTPS** : redirection 301 automatique
- **SSL** : certificat Let's Encrypt pour `mcp.amia.fr`
- **Reverse proxy** : toutes les requetes → `http://127.0.0.1:14500`
- **WebSocket** : upgrade automatique pour `/ws`
- **CORS** : headers `Access-Control-Allow-*` pour Smithery et Claude Desktop

### 6.2 Certificat SSL

Le sous-domaine `mcp.amia.fr` utilise un certificat Let's Encrypt. Si le certificat principal d'`amia.fr` ne couvre pas le sous-domaine :

```bash
sudo certbot --apache -d mcp.amia.fr
```

Si le certificat existe deja (comme dans notre cas), les chemins sont :
- `/etc/letsencrypt/live/mcp.amia.fr/fullchain.pem`
- `/etc/letsencrypt/live/mcp.amia.fr/privkey.pem`

### 6.3 Modules Apache requis

```bash
sudo a2enmod proxy proxy_http proxy_wstunnel ssl headers rewrite
```

### 6.4 Diagnostic

```bash
sudo apache2ctl configtest          # Verifier la syntaxe
sudo systemctl status apache2       # Statut du service
tail -f /var/log/apache2/mcp.amia.fr-error.log   # Logs d'erreur
tail -f /var/log/apache2/mcp.amia.fr-access.log  # Logs d'acces
```

---

## 7. PM2 — Gestion du processus

### 7.1 ecosystem.config.cjs

Le fichier PM2 :
- **Parse le `.env`** automatiquement (pas besoin de `dotenv`)
- **Mode fork** (pas cluster — le serveur gere ses propres workers)
- **Autorestart** : redemarre automatiquement en cas de crash
- **Limite memoire** : restart si > 512 Mo
- **Logs dates** : format `YYYY-MM-DD HH:mm:ss`

### 7.2 Commandes PM2

```bash
# Gestion
pm2 start ecosystem.config.cjs     # Premier demarrage
pm2 restart octonet-mcp             # Redemarrage
pm2 reload octonet-mcp              # Reload zero-downtime
pm2 stop octonet-mcp                # Arreter
pm2 delete octonet-mcp              # Supprimer du registre PM2

# Apres modification du .env
pm2 restart octonet-mcp --update-env

# Monitoring
pm2 status                          # Vue d'ensemble
pm2 logs octonet-mcp                # Logs en temps reel
pm2 logs octonet-mcp --lines 50     # 50 dernieres lignes
pm2 monit                           # Dashboard terminal

# Persistence
pm2 save                            # Sauvegarder la liste des processus
pm2 startup                         # Configurer le demarrage automatique
pm2 unstartup                       # Retirer le demarrage automatique
```

### 7.3 Demarrage automatique au boot

```bash
# Generer la commande de startup
pm2 startup systemd -u hmd --hp /home/hmd

# Executer la commande sudo affichee
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u hmd --hp /home/hmd

# Sauvegarder l'etat actuel
pm2 save
```

Apres un reboot du serveur, PM2 redemarrera automatiquement `octonet-mcp`.

---

## 8. Publication sur les annuaires MCP

### 8.1 Registre officiel MCP (registry.modelcontextprotocol.io)

#### Prerequis
- `mcp-publisher` installe (binaire Go)
- `server.json` a la racine du repo `mosta-net`
- `mcpName` dans `package.json` de `@mostajs/net`

#### Installation de mcp-publisher

```bash
curl -L "https://github.com/modelcontextprotocol/registry/releases/latest/download/mcp-publisher_linux_amd64.tar.gz" | tar xz mcp-publisher
mv mcp-publisher ~/.local/bin/
```

#### Fichier server.json

```json
{
  "$schema": "https://static.modelcontextprotocol.io/schemas/2025-12-11/server.schema.json",
  "name": "io.github.apolocine/mosta-net",
  "description": "1 MCP server, 13 databases, zero config.",
  "repository": {
    "url": "https://github.com/apolocine/mosta-net",
    "source": "github"
  },
  "version": "2.0.45",
  "packages": [
    {
      "registryType": "npm",
      "identifier": "@mostajs/net",
      "version": "2.0.45",
      "transport": { "type": "stdio" }
    }
  ]
}
```

#### Champ mcpName dans package.json

```json
{
  "mcpName": "io.github.apolocine/mosta-net"
}
```

#### Commandes de publication

```bash
# Authentification GitHub OAuth
~/.local/bin/mcp-publisher login github

# Validation
~/.local/bin/mcp-publisher validate

# Publication
~/.local/bin/mcp-publisher publish
```

L'authentification utilise GitHub Device Flow : un code s'affiche, vous le saisissez sur https://github.com/login/device.

### 8.2 Smithery.ai

#### Prerequis
- Compte Smithery.ai
- CLI `@smithery/cli` (via npx)
- Serveur MCP accessible publiquement (https://mcp.amia.fr/mcp)

#### Authentification

```bash
npx @smithery/cli auth login
# Ouvre un navigateur pour l'autorisation
```

#### Creation du serveur (premiere fois)

Le serveur a ete cree via l'API REST :

```bash
curl -s -X PUT "https://registry.smithery.ai/servers/mostajs/octonet-mcp" \
  -H "Authorization: Bearer <SMITHERY_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{
    "qualifiedName": "mostajs/octonet-mcp",
    "displayName": "OctoNet MCP",
    "description": "1 MCP server, 13 databases, zero config. 15 tools per entity + 4 AI prompts."
  }'
```

#### Publication (mode external — gratuit)

```bash
npx @smithery/cli mcp publish https://mcp.amia.fr/mcp --name mostajs/octonet-mcp
```

Smithery se connecte a l'URL, scanne les tools (45 tools detectes), et publie la release.

#### Verification

```bash
curl -s "https://registry.smithery.ai/servers/mostajs/octonet-mcp" | python3 -m json.tool
```

#### Mise a jour apres modification

```bash
# Apres changement de schemas ou mise a jour npm
pm2 restart octonet-mcp --update-env
npx @smithery/cli mcp publish https://mcp.amia.fr/mcp --name mostajs/octonet-mcp
```

### 8.3 mcp.so

mcp.so est un agregateur qui indexe automatiquement le registre officiel MCP. Apres publication sur le registre officiel (8.1), le serveur apparait automatiquement sur mcp.so.

Soumission manuelle alternative : https://mcp.so/submit → coller l'URL du repo GitHub.

### 8.4 Fichier smithery.yaml

Le fichier `smithery.yaml` a la racine du repo `mosta-net` permet a Smithery de detecter le serveur :

```yaml
name: octonet-mcp
description: "1 MCP server, 13 databases, zero config."
startCommand:
  type: stdio
  command: npx
  args: ["octonet-mcp", "--dialect=sqlite", "--uri=:memory:"]
```

### 8.5 Fonction createSandboxServer

Pour que Smithery puisse scanner les tools en mode build local, le fichier `mcp-cli.ts` exporte une fonction sandbox :

```typescript
export default function createSandboxServer(): McpServer {
  // Cree un McpServer avec des schemas de demo
  // Enregistre 15 tools par entite + 4 prompts
  // Smithery appelle cette fonction lors du scan
}
```

---

## 9. Depot GitHub octonet-mcp

### 9.1 Structure du depot

```
octonet-mcp/
├── README.md                     # Documentation principale
├── LICENSE                       # AGPL-3.0-or-later
├── .env.production               # Template des variables d'environnement
├── ecosystem.config.cjs          # Configuration PM2
├── schemas.json                  # Schemas des entites de demo
├── install.sh                    # Script d'installation automatique
├── apache/
│   └── mcp.amia.fr.conf          # VirtualHost Apache
└── docs/
    └── GUIDE-DEPLOIEMENT.md      # Ce document
```

### 9.2 Repo GitHub

- **URL** : https://github.com/apolocine/octonet-mcp
- **Visibilite** : public
- **Description** : OctoNet MCP — Deploy kit for mcp.amia.fr

### 9.3 Relation avec mosta-net

| Depot | Contenu | npm |
|---|---|---|
| `apolocine/mosta-net` | Code source du serveur, transports, MCP | `@mostajs/net` |
| `apolocine/octonet-mcp` | Kit de deploiement, config, scripts | — |

`octonet-mcp` ne contient pas de code source — c'est un kit de deploiement qui installe `@mostajs/net` depuis npm.

---

## 10. Verification et tests

### 10.1 Test du endpoint MCP

```bash
# Initialize (handshake MCP)
curl -s https://mcp.amia.fr/mcp \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":1}'
```

Reponse attendue :
```json
{"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{"listChanged":true},"resources":{"listChanged":true},"prompts":{"listChanged":true}},"serverInfo":{"name":"OctoNet MCP","version":"2.0.0"}},"jsonrpc":"2.0","id":1}
```

### 10.2 Test REST API

```bash
# Lister les utilisateurs
curl -s https://mcp.amia.fr/api/v1/users | python3 -m json.tool

# Creer un utilisateur
curl -s https://mcp.amia.fr/api/v1/users \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","name":"Test User"}'
```

### 10.3 Test Dashboard

Ouvrir https://mcp.amia.fr/ dans un navigateur — le dashboard IHM affiche :
- Configuration active
- Schema des entites
- API Explorer
- MCP Agent Simulator

### 10.4 Test Claude Desktop

Ajouter dans `claude_desktop_config.json` :

```json
{
  "mcpServers": {
    "octonet": {
      "url": "https://mcp.amia.fr/mcp"
    }
  }
}
```

Puis dans Claude Desktop, demander : "Liste tous les utilisateurs via OctoNet".

### 10.5 Verification Smithery

```bash
# Verifier que les tools sont scannes
curl -s "https://registry.smithery.ai/servers/mostajs/octonet-mcp" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(f'Tools: {len(d.get(\"tools\") or [])}')
print(f'Remote: {d.get(\"remote\")}')
print(f'URL: {d.get(\"deploymentUrl\")}')
"
```

Resultat attendu :
```
Tools: 45
Remote: True
URL: https://octonet-mcp--mostajs.run.tools
```

---

## 11. Maintenance et mise a jour

### 11.1 Mise a jour du package npm

```bash
ssh amia "cd /home/hmd/prod/octonet-mcp && npm update @mostajs/net @mostajs/orm @mostajs/mproject && pm2 restart octonet-mcp"
```

### 11.2 Mise a jour des schemas

1. Editer `schemas.json` sur le serveur
2. Redemarrer : `pm2 restart octonet-mcp`
3. Re-publier sur Smithery pour mettre a jour les tools :
   ```bash
   npx @smithery/cli mcp publish https://mcp.amia.fr/mcp --name mostajs/octonet-mcp
   ```

### 11.3 Mise a jour du registre officiel MCP

Apres bump de version npm :

1. Editer `server.json` dans `mosta-net` (mettre la nouvelle version)
2. `~/.local/bin/mcp-publisher validate`
3. `~/.local/bin/mcp-publisher publish`

### 11.4 Monitoring

```bash
# Statut PM2
ssh amia "pm2 status"

# Logs temps reel
ssh amia "pm2 logs octonet-mcp"

# Utilisation memoire/CPU
ssh amia "pm2 monit"

# Logs Apache
ssh amia "tail -f /var/log/apache2/mcp.amia.fr-access.log"
```

---

## 12. Problemes rencontres et solutions

| # | Probleme | Cause | Solution |
|---|---|---|---|
| 1 | `mcp-publisher publish` erreur 400 | server.json referencait v2.0.41, npm avait v2.0.42 | Aligner les versions dans server.json |
| 2 | Smithery esbuild `Could not resolve "better-sqlite3"` | Import statique d'un module natif C++ | Import dynamique avec concatenation de string (`'better-sqlite' + '3'`) |
| 3 | Smithery scan `t.default is not a function` | Named export au lieu de default export | `export default function createSandboxServer()` |
| 4 | Smithery `403 Hosted deployments require paid plan` | Plan gratuit ne supporte pas le hosted | Mode `external` avec URL publique (gratuit) |
| 5 | PM2 crash loop (banner + exit) | `env_file` pas supporte par PM2, variables non chargees | Parser le `.env` dans ecosystem.config.cjs avec `readFileSync` |
| 6 | PM2 `Could not create folder /opt/octonet-mcp/logs` | Chemin en dur dans ecosystem ne correspondait pas au repertoire reel | Utiliser `__dirname` et `resolve()` dans ecosystem |
| 7 | `git push master` rejete | PR mergee avait cree un commit de merge distant | `git pull --rebase` avant push |
| 8 | certbot erreur sur `mcp.amia.fr` | Certificat deja genere pour le sous-domaine | Reutiliser les chemins existants dans `/etc/letsencrypt/live/mcp.amia.fr/` |
| 9 | Conflit VirtualHost Apache | `ServerAlias mcp.amia.fr` dans le VHost d'amia.fr | Retirer la ligne avec `sed -i` |

---

## 13. Reference des fichiers

### Sur le serveur (amia.fr)

| Chemin | Description |
|---|---|
| `/home/hmd/prod/octonet-mcp/` | Repertoire de l'application |
| `/home/hmd/prod/octonet-mcp/.env` | Variables d'environnement actives |
| `/home/hmd/prod/octonet-mcp/ecosystem.config.cjs` | Configuration PM2 |
| `/home/hmd/prod/octonet-mcp/schemas.json` | Schemas des entites |
| `/home/hmd/prod/octonet-mcp/logs/` | Logs PM2 (out.log, error.log) |
| `/home/hmd/prod/octonet-mcp/node_modules/` | Dependances npm |
| `/etc/apache2/sites-available/mcp.amia.fr.conf` | VirtualHost Apache |
| `/etc/letsencrypt/live/mcp.amia.fr/` | Certificats SSL |
| `/var/log/apache2/mcp.amia.fr-*.log` | Logs Apache |

### Sur le poste de developpement

| Chemin | Description |
|---|---|
| `~/.local/bin/mcp-publisher` | Binaire Go pour le registre officiel MCP |
| `mostajs/mosta-net/server.json` | Declaration pour le registre officiel MCP |
| `mostajs/mosta-net/smithery.yaml` | Declaration pour Smithery |
| `mostajs/mosta-net/src/mcp-cli.ts` | CLI + createSandboxServer() |
| `Entreprise/octonet-mcp/` | Kit de deploiement (ce depot) |
| `Entreprise/Publication-MCP-Annuaires.md` | Journal de la publication |

### Comptes et acces

| Service | Compte | Auth |
|---|---|---|
| npm | via `npm login` | Token npm |
| GitHub | `apolocine` | SSH key |
| Registre MCP | `io.github.apolocine` | GitHub OAuth |
| Smithery.ai | `mostajs` (namespace) | API key + CLI login |
| Serveur amia.fr | `hmd` | SSH key (alias `amia`) |
