# kiln

Where you fire a mache.

## Table of contents

- [What's inside](#whats-inside)
- [Quick start](#quick-start)
- [Editor setup](#editor-setup)
- [Building](#building)
- [Distribution](#distribution)
- [Architecture](#architecture)
- [License](#license)

Kiln packages [mache](https://github.com/agentic-research/mache) and
[ley-line](https://github.com/agentic-research/ley-line) into a single
artifact — either a static fat binary or a distroless OCI image. One
command gives you a fully wired MCP server backed by ley-line's zero-copy
arena.

## What's inside

```mermaid
graph TD
    subgraph kiln["kiln (fat binary)"]
        subgraph mache["mache (Go)"]
            Schema[Schema]
            Ingest[Ingest]
            MCP[MCP Server]
        end

        subgraph leyline["ley-line (Rust)"]
            Arena[Arena]
            SQLite[SQLite]
            Graph[Graph]
        end

        mache -->|C FFI| leyline
    end

    MCP -->|"Streamable HTTP :7532"| Client["MCP Clients"]
```

## Quick start

### As a binary

```bash
task binary
./bin/mache serve /path/to/your/code
```

### As an OCI image

```bash
# Build distroless image via melange + apko
task apk

# Run it
docker run -i --rm \
  -v $(pwd):/source:ro \
  -v kiln-cache:/data \
  kiln /source
```

## Editor setup

Mache serves an MCP endpoint over Streamable HTTP on `:7532` by default.
Start the server, then point your editor at it.

### 1. Start the server

```bash
# Serve a codebase (HTTP on :7532 by default)
mache serve /path/to/your/code

# Or with a specific schema
mache serve -s examples/go-schema.json ./internal/

# Background via brew (macOS)
brew services start agentic-research/tap/mache
```

### 2. Connect your editor

#### Claude Code

```bash
# One-liner (HTTP — recommended)
claude mcp add --transport http mache http://localhost:7532/mcp

# Or stdio mode (Claude manages the process)
claude mcp add mache -- mache serve --stdio /path/to/your/code
```

#### VS Code / Cursor

Add to your `.vscode/mcp.json` (or global `settings.json` under `"mcp"`):

```json
{
  "servers": {
    "mache": {
      "type": "http",
      "url": "http://localhost:7532/mcp"
    }
  }
}
```

For stdio mode:

```json
{
  "servers": {
    "mache": {
      "type": "stdio",
      "command": "mache",
      "args": ["serve", "--stdio", "/path/to/your/code"]
    }
  }
}
```

#### Gemini CLI

Add to `~/.gemini/settings.json`:

```json
{
  "mcpServers": {
    "mache": {
      "httpUrl": "http://localhost:7532/mcp"
    }
  }
}
```

#### Windsurf

Add to `~/.codeium/windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "mache": {
      "serverUrl": "http://localhost:7532/mcp"
    }
  }
}
```

#### Container mode (any editor)

For stdio-based editors that don't support HTTP transport:

```json
{
  "mcpServers": {
    "mache": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "${workspaceFolder}:/source:ro",
        "-v", "mache-cache:/data",
        "mache", "--stdio", "/source"
      ]
    }
  }
}
```

## Building

All commands use [Task](https://taskfile.dev).

```bash
task binary       # Static fat binary (Go + Rust linked)
task image        # Dockerfile image (dev/iteration)
task apk          # melange + apko distroless image (release)
task sign         # cosign signature (uses signet KMS if available)
task test         # Smoke test
task shell        # Debug shell in container
task clean        # Remove artifacts
```

### Build requirements

**Binary**: Go 1.23+, Rust 1.82+, C compiler.
**Image** (Dockerfile): Docker or Podman. No local toolchains.
**Image** (apko): melange, apko. Produces reproducible distroless images.

## Distribution

Three tiers, same binary inside:

| Method | Target | Size | Reproducible |
|--------|--------|------|--------------|
| `task binary` | Direct install, Homebrew tap | ~30MB | No (host-dependent) |
| `task image` | Dev, CI | ~200MB | No |
| `task apk` | Release, registry | ~15-20MB | Yes |

The apko path produces a distroless image: no shell, no package manager,
just the mache binary + musl libc + ca-certs. Signed with cosign, optionally
via signet's KMS provider.

## Architecture

Kiln is glue, not logic. It owns:

- **Build pipeline** — multi-language compilation + static linking
- **Packaging** — melange APK + apko OCI image assembly
- **Volume contract** — `/source` (read-only bind), `/data` (persistent cache)
- **Signing** — cosign + optional signet KMS integration

Kiln does NOT own:

- Schema logic, ingestion, tree-sitter queries (that's mache)
- Arena format, double-buffering, SQLite adapter (that's ley-line)

## Why?

Mache is Go. Ley-line is Rust. They talk via C FFI (`cgo` + `staticlib`).
Building locally requires both toolchains, a C compiler, platform-specific
FUSE/NFS libs, and the right CGO flags. Kiln absorbs that complexity so
users get one thing that works.

## Status

Early. The pieces exist — mache already links ley-line's staticlib via FFI.
Kiln just puts them in a box and fires it.

## License

Apache-2.0 (kiln and mache). Ley-line is closed-source.
