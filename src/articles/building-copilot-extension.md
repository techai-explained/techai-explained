---
title: "Building Your First Copilot Extension in 30 Minutes"
description: "A step-by-step guide to building a GitHub Copilot Extension — from project setup to deployment — with a working code example you can ship today."
date: 2026-03-17
tags: ["Developer Tools"]
readTime: "10 min read"
---

GitHub Copilot Extensions let you build custom AI-powered tools that integrate directly into the Copilot chat experience. Instead of your users switching context to a separate tool, they can invoke your extension with `@your-extension` right inside their editor or CLI.

This tutorial walks you through building a working extension from scratch. By the end, you'll have a deployed Copilot Extension that answers questions about any GitHub repository's structure.

## What You'll Build

A **Repo Explorer** extension that lets users type `@repo-explorer what's the architecture of this project?` and get an intelligent summary of the repository structure, key files, and technology stack.

<div class="diagram-box">
┌─────────────────────────────────────────────────┐
│              USER IN COPILOT CHAT               │
│                                                 │
│  @repo-explorer what does this project do?      │
│                                                 │
│         │                                       │
│         ▼                                       │
│  ┌─────────────────┐    ┌──────────────────┐    │
│  │ Copilot Platform │───►│ Your Extension   │   │
│  │ (Routes request) │    │ (Node.js server) │   │
│  └─────────────────┘    └──────────────────┘    │
│                                │                │
│                                ▼                │
│                     ┌──────────────────┐        │
│                     │  Response with   │        │
│                     │  repo analysis   │        │
│                     └──────────────────┘        │
└─────────────────────────────────────────────────┘
</div>

## Prerequisites

- Node.js 20+
- A GitHub account
- Basic familiarity with Express.js
- GitHub CLI (`gh`) installed

## Step 1: Scaffold the Project

```bash
mkdir copilot-repo-explorer
cd copilot-repo-explorer
npm init -y
npm install express @octokit/rest
npm install -D typescript @types/node @types/express tsx
```

Initialize TypeScript:

```bash
npx tsc --init --target ES2022 --module NodeNext \
  --moduleResolution NodeNext --outDir dist \
  --rootDir src --strict
```

Create the project structure:

```
copilot-repo-explorer/
├── src/
│   ├── index.ts          # Express server
│   ├── handler.ts        # Copilot message handler
│   └── repo-analyzer.ts  # GitHub API integration
├── package.json
└── tsconfig.json
```

## Step 2: Build the Message Handler

Copilot Extensions receive messages via Server-Sent Events (SSE). Your server receives a POST request with the user's message and responds with a stream.

```typescript
// src/handler.ts
import { IncomingMessage, ServerResponse } from "node:http";

interface CopilotMessage {
  role: "user" | "assistant";
  content: string;
}

interface CopilotRequest {
  messages: CopilotMessage[];
}

export async function handleCopilotRequest(
  req: IncomingMessage,
  res: ServerResponse,
  body: CopilotRequest
) {
  // Set SSE headers
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });

  const userMessage = body.messages
    .filter((m) => m.role === "user")
    .pop()?.content;

  if (!userMessage) {
    sendSSEMessage(res, "I didn't receive a message. Try again!");
    res.end();
    return;
  }

  // Analyze the repo
  const analysis = await analyzeCurrentRepo(userMessage);
  sendSSEMessage(res, analysis);
  res.end();
}

function sendSSEMessage(res: ServerResponse, content: string) {
  const data = JSON.stringify({
    choices: [{
      index: 0,
      delta: { content, role: "assistant" },
    }],
  });
  res.write(`data: ${data}\n\n`);
  res.write("data: [DONE]\n\n");
}
```

## Step 3: Build the Repo Analyzer

This is the core logic. It reads the repository tree from GitHub and generates an intelligent summary.

```typescript
// src/repo-analyzer.ts
import { Octokit } from "@octokit/rest";

interface RepoStructure {
  languages: string[];
  keyFiles: string[];
  directories: string[];
  framework: string | null;
}

export async function analyzeRepo(
  owner: string,
  repo: string,
  token: string
): Promise<RepoStructure> {
  const octokit = new Octokit({ auth: token });

  // Get repository tree
  const { data: tree } = await octokit.git.getTree({
    owner, repo,
    tree_sha: "HEAD",
    recursive: "true",
  });

  const files = tree.tree
    .filter((item) => item.type === "blob")
    .map((item) => item.path!);

  // Detect languages
  const extensions = files
    .map((f) => f.split(".").pop())
    .filter(Boolean);
  const langCounts = extensions.reduce((acc, ext) => {
    acc[ext!] = (acc[ext!] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  const languages = Object.entries(langCounts)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 5)
    .map(([ext]) => extensionToLanguage(ext));

  // Detect framework
  const framework = detectFramework(files);

  // Find key files
  const keyPatterns = [
    /readme/i, /contributing/i, /dockerfile/i,
    /docker-compose/i, /\.github\/workflows/,
    /package\.json$/, /go\.mod$/, /cargo\.toml$/,
  ];
  const keyFiles = files
    .filter((f) => keyPatterns.some((p) => p.test(f)))
    .slice(0, 10);

  // Top-level directories
  const directories = [...new Set(
    files.filter((f) => f.includes("/"))
      .map((f) => f.split("/")[0])
  )].slice(0, 15);

  return { languages, keyFiles, directories, framework };
}

function detectFramework(files: string[]): string | null {
  if (files.some((f) => f.includes("next.config"))) return "Next.js";
  if (files.some((f) => f.includes("angular.json"))) return "Angular";
  if (files.some((f) => f.includes("nuxt.config"))) return "Nuxt";
  if (files.some((f) => /\.csproj$/.test(f))) return ".NET";
  if (files.some((f) => f.includes("go.mod"))) return "Go";
  if (files.some((f) => f.includes("Cargo.toml"))) return "Rust";
  return null;
}

function extensionToLanguage(ext: string): string {
  const map: Record<string, string> = {
    ts: "TypeScript", js: "JavaScript", py: "Python",
    go: "Go", rs: "Rust", cs: "C#", java: "Java",
    rb: "Ruby", php: "PHP", swift: "Swift",
    kt: "Kotlin", md: "Markdown", yml: "YAML",
  };
  return map[ext] || ext;
}
```

## Step 4: Wire Up the Express Server

```typescript
// src/index.ts
import express from "express";
import { handleCopilotRequest } from "./handler.js";

const app = express();
app.use(express.json());

// Health check
app.get("/", (_req, res) => {
  res.json({ status: "ok", extension: "repo-explorer" });
});

// Copilot Extension endpoint
app.post("/agent", async (req, res) => {
  try {
    await handleCopilotRequest(req, res, req.body);
  } catch (error) {
    console.error("Handler error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Repo Explorer extension running on port ${PORT}`);
});
```

Add the start script to `package.json`:

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js"
  }
}
```

## Step 5: Test Locally

Start the development server:

```bash
npm run dev
```

Test with curl:

```bash
curl -X POST http://localhost:3000/agent \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "What is this project about?"}
    ]
  }'
```

You should see an SSE response with the analysis.

## Step 6: Register as a GitHub App

1. Go to **Settings → Developer Settings → GitHub Apps → New GitHub App**
2. Fill in:
   - **Name:** `repo-explorer-extension`
   - **Homepage URL:** Your deployment URL
   - **Callback URL:** `https://your-domain.com/auth/callback`
   - **Webhook URL:** `https://your-domain.com/webhook`
3. Under **Copilot**, enable the extension and set the endpoint to `https://your-domain.com/agent`
4. Set permissions: `Repository contents: Read`

## Step 7: Deploy

For quick deployment, use any Node.js hosting platform:

```bash
# Build for production
npm run build

# Deploy (example with a container)
docker build -t repo-explorer .
docker push your-registry/repo-explorer
```

Here's a minimal `Dockerfile`:

```dockerfile
FROM node:20-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY dist/ ./dist/
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

## How the Extension Protocol Works

Understanding the protocol helps you debug issues:

<div class="diagram-box">
1. User types: @repo-explorer analyze this repo
                    │
2. Copilot Platform │ POST /agent
   sends request ───┘ { messages: [...] }
                    │
3. Your server      │ SSE Response
   streams back ────┘ data: {"choices":[...]}
                    │  data: [DONE]
                    │
4. Copilot renders  │
   the response ────┘ Markdown in chat UI
</div>

Key points:
- **Authentication**: The platform sends a `X-GitHub-Token` header you can use to make API calls on behalf of the user
- **Streaming**: Use SSE format — the response renders progressively in the chat
- **Markdown**: Your response is rendered as Markdown, so use formatting, code blocks, and lists

## Adding Slash Commands

Make your extension more powerful with slash commands:

```typescript
// Parse slash commands from the user message
function parseCommand(message: string): { command: string; args: string } {
  const match = message.match(/^\/(\w+)\s*(.*)/);
  if (match) {
    return { command: match[1], args: match[2] };
  }
  return { command: "default", args: message };
}

// In your handler:
const { command, args } = parseCommand(userMessage);

switch (command) {
  case "structure":
    return analyzeStructure(args);
  case "deps":
    return analyzeDependencies(args);
  case "security":
    return securityScan(args);
  default:
    return generalAnalysis(args);
}
```

Users can then type:
- `@repo-explorer /structure` — show project structure
- `@repo-explorer /deps` — analyze dependencies
- `@repo-explorer /security` — run security checks

## Common Pitfalls

1. **Forgetting SSE format** — Copilot expects Server-Sent Events, not a regular JSON response
2. **Not handling the token** — use `X-GitHub-Token` for API calls; don't hardcode tokens
3. **Slow responses** — stream partial results so users see progress
4. **No error handling** — always send a user-friendly error message instead of crashing

## Next Steps

You now have a working Copilot Extension. Here's where to go next:

- Add **caching** to avoid redundant GitHub API calls
- Implement **conversation memory** so follow-up questions work
- Add more **slash commands** for specialized analysis
- Deploy behind a **CDN** for global performance
- Submit to the **GitHub Marketplace** for public distribution

The Copilot Extensions ecosystem is new and growing fast. Building an extension now means you're in early — when the marketplace scales, your extension is already there.

*Published by the TechAI Explained Team.*
