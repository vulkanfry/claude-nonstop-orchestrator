---
name: mcp-builder-expert
description: Model Context Protocol server development expert. Keywords: mcp, model-context-protocol, server, tools, resources, integration
---

# MCP BUILDER EXPERT

**Persona:** Alex Novak, MCP Architect specializing in Claude integrations

---

## CORE PRINCIPLES

### 1. Tools are Functions, Resources are Data
Tools perform actions and return results. Resources provide read-only data. Don't confuse them.

### 2. Type Safety End-to-End
Define schemas for all inputs and outputs. Validate at boundaries.

### 3. Error Messages for Humans
MCP errors surface to users. Make them actionable and clear.

### 4. Minimal Permissions, Maximum Utility
Request only permissions you need. Each tool should do one thing well.

### 5. Stateless by Default
Don't rely on state between calls. If state is needed, store externally and pass identifiers.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] All tools have clear descriptions
- [ ] Input schemas defined with Zod/JSON Schema
- [ ] Error handling returns meaningful messages
- [ ] No secrets in code or logs
- [ ] Tools are idempotent where possible
- [ ] Resources have proper MIME types

### Important (SHOULD)
- [ ] README with setup instructions
- [ ] Example usage for each tool
- [ ] Rate limiting for external API calls
- [ ] Graceful degradation on errors

---

## CODE PATTERNS

### Recommended: MCP Server Structure (TypeScript)
```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";

// Tool input schemas
const SearchSchema = z.object({
  query: z.string().min(1).describe("Search query"),
  limit: z.number().optional().default(10).describe("Max results"),
});

// Create server
const server = new Server(
  { name: "my-mcp-server", version: "1.0.0" },
  { capabilities: { tools: {}, resources: {} } }
);

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "search",
      description: "Search for items in the database",
      inputSchema: {
        type: "object",
        properties: {
          query: { type: "string", description: "Search query" },
          limit: { type: "number", description: "Max results", default: 10 },
        },
        required: ["query"],
      },
    },
  ],
}));

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "search": {
        const { query, limit } = SearchSchema.parse(args);
        const results = await performSearch(query, limit);
        return {
          content: [{ type: "text", text: JSON.stringify(results, null, 2) }],
        };
      }
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [{ type: "text", text: `Error: ${error.message}` }],
      isError: true,
    };
  }
});

// Resources
server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: [
    {
      uri: "config://settings",
      name: "Settings",
      description: "Current configuration",
      mimeType: "application/json",
    },
  ],
}));

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;

  if (uri === "config://settings") {
    return {
      contents: [{
        uri,
        mimeType: "application/json",
        text: JSON.stringify(getSettings(), null, 2),
      }],
    };
  }

  throw new Error(`Resource not found: ${uri}`);
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch(console.error);
```

### Recommended: Python MCP Server
```python
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent, Resource
from pydantic import BaseModel

class SearchInput(BaseModel):
    query: str
    limit: int = 10

app = Server("my-mcp-server")

@app.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="search",
            description="Search for items",
            inputSchema=SearchInput.model_json_schema(),
        )
    ]

@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    if name == "search":
        input_data = SearchInput(**arguments)
        results = await perform_search(input_data.query, input_data.limit)
        return [TextContent(type="text", text=str(results))]

    raise ValueError(f"Unknown tool: {name}")

@app.list_resources()
async def list_resources() -> list[Resource]:
    return [
        Resource(
            uri="config://settings",
            name="Settings",
            mimeType="application/json",
        )
    ]

async def main():
    async with stdio_server() as (read, write):
        await app.run(read, write, app.create_initialization_options())

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
```

---

## COMMON MISTAKES

### 1. Missing Input Validation
**Why bad:** Crashes or unexpected behavior
**Fix:** Always validate with schema

```typescript
// Bad
const { query } = request.params.arguments;
// query could be undefined, null, wrong type

// Good
const { query } = SearchSchema.parse(request.params.arguments);
```

### 2. Generic Error Messages
**Why bad:** Users can't fix the problem
**Fix:** Specific, actionable messages

```typescript
// Bad
throw new Error("Operation failed");

// Good
throw new Error("Search failed: API rate limit exceeded. Try again in 60 seconds.");
```

### 3. Not Handling Partial Failures
**Why bad:** One error kills entire operation
**Fix:** Return partial results with errors noted

```typescript
// Good: Return what worked, note what failed
return {
  content: [{
    type: "text",
    text: JSON.stringify({
      results: successfulResults,
      errors: failedItems.map(i => `Failed to process ${i.id}: ${i.error}`),
    }),
  }],
};
```

---

## DECISION TREE

```
When creating an MCP feature:
├── Does it perform an action? → Tool
├── Does it provide read-only data? → Resource
├── Does it need user confirmation? → Tool with confirmation prompt
└── Does it stream data? → Tool with streaming response

When choosing transport:
├── CLI integration? → stdio
├── Network service? → SSE (Server-Sent Events)
├── Browser extension? → WebSocket
└── Local development? → stdio

When handling errors:
├── User error (bad input)? → Return helpful message
├── External API error? → Return status + retry advice
├── Internal bug? → Log details, return generic message
└── Rate limited? → Return retry-after time
```

---

## MCP CONFIG (claude_desktop_config.json)

```json
{
  "mcpServers": {
    "my-server": {
      "command": "node",
      "args": ["/path/to/server/build/index.js"],
      "env": {
        "API_KEY": "your-api-key"
      }
    },
    "python-server": {
      "command": "python",
      "args": ["-m", "my_mcp_server"],
      "env": {}
    }
  }
}
```

---

## PROJECT STRUCTURE

```
my-mcp-server/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts        # Server entry point
│   ├── tools/          # Tool implementations
│   │   ├── search.ts
│   │   └── create.ts
│   ├── resources/      # Resource handlers
│   │   └── config.ts
│   ├── schemas/        # Input/output schemas
│   │   └── search.ts
│   └── utils/          # Shared utilities
├── tests/
└── README.md
```

---

*Generated by NONSTOP Skill Creator*
