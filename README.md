# OctoNet MCP — Deploy Kit

> **1 MCP server, 13 databases, zero config.**
> Production deployment for [mcp.amia.fr](https://mcp.amia.fr) — powered by [@mostajs/net](https://github.com/apolocine/mosta-net).

<p align="center">
  <img src="https://raw.githubusercontent.com/apolocine/mosta-net/master/logo/octonet-icon.svg" width="128" alt="OctoNet Logo"/>
</p>

## Live Endpoints

| Endpoint | URL |
|---|---|
| **MCP (AI Agents)** | `https://mcp.amia.fr/mcp` |
| **Dashboard IHM** | https://mcp.amia.fr/ |
| **REST API** | https://mcp.amia.fr/api/v1/ |
| **GraphQL** | https://mcp.amia.fr/graphql |
| **WebSocket** | `wss://mcp.amia.fr/ws` |
| **SSE** | https://mcp.amia.fr/events |
| **JSON-RPC** | https://mcp.amia.fr/rpc |
| **tRPC** | https://mcp.amia.fr/trpc/ |
| **OData** | https://mcp.amia.fr/odata/ |

## Scripts

| Script | Usage | Description |
|---|---|---|
| `deploy.sh` | `./deploy.sh [ssh-alias] [remote-dir]` | Deploie depuis le poste local vers le serveur |
| `install.sh` | `sudo ./install.sh [app-dir]` | Installation complete sur le serveur (Node, PM2, Apache) |
| `update.sh` | `./update.sh` | Mise a jour rapide npm + PM2 restart (sur le serveur) |

### Deploiement rapide (depuis le poste local)

```bash
./deploy.sh amia /home/hmd/prod/octonet-mcp
```

### Premiere installation (sur le serveur)

```bash
sudo ./install.sh /home/hmd/prod/octonet-mcp
```

### Mise a jour (sur le serveur ou via ssh)

```bash
ssh amia '/home/hmd/prod/octonet-mcp/update.sh'
```

## Registres

| Plateforme | Lien |
|---|---|
| **npm** | [@mostajs/net](https://www.npmjs.com/package/@mostajs/net) |
| **MCP Registry** | `io.github.apolocine/mosta-net` |
| **Smithery.ai** | [mostajs/octonet-mcp](https://smithery.ai/servers/mostajs/octonet-mcp) |
| **mcp.so** | [octonet-mcp](https://mcp.so/server/octonet-mcp/apolocine) |

## Claude Desktop Configuration

```json
{
  "mcpServers": {
    "octonet": {
      "url": "https://mcp.amia.fr/mcp"
    }
  }
}
```

Or run locally:

```json
{
  "mcpServers": {
    "octonet": {
      "command": "npx",
      "args": ["octonet-mcp", "--dialect=sqlite", "--uri=:memory:"]
    }
  }
}
```

## Files

```
octonet-mcp/
├── deploy.sh              # Deploiement local → serveur
├── install.sh             # Installation complete sur serveur
├── update.sh              # Mise a jour rapide
├── .env.production        # Template variables d'environnement
├── ecosystem.config.cjs   # Configuration PM2
├── schemas.json           # Schemas de demo (User, Product, Order)
├── apache/
│   └── mcp.amia.fr.conf  # VirtualHost Apache SSL
└── docs/
    └── GUIDE-DEPLOIEMENT.md  # Documentation complete
```

## Author

Dr Hamid MADANI <drmdh@msn.com>

## License

AGPL-3.0-or-later
