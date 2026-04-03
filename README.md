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

## Registres

| Plateforme | Lien |
|---|---|
| **npm** | [@mostajs/net](https://www.npmjs.com/package/@mostajs/net) |
| **MCP Registry** | `io.github.apolocine/mosta-net` |
| **Smithery.ai** | [mostajs/octonet-mcp](https://smithery.ai/servers/mostajs/octonet-mcp) |

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

## Author

Dr Hamid MADANI <drmdh@msn.com>

## License

AGPL-3.0-or-later
