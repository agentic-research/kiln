# kiln

Where you fire a mache.

Kiln packages [mache](https://github.com/mache-org/mache) and
[ley-line](https://github.com/agentic-research/ley-line) into a single
artifact — either a static fat binary or a distroless OCI image. One
command gives you a fully wired MCP server backed by ley-line's zero-copy
arena.

## What's inside

```
┌────────────────────────────────────────┐
│  kiln                                  │
│                                        │
│  mache (Go)          ley-line (Rust)   │
│  ┌──────────┐        ┌─────────────┐  │
│  │ schema   │──FFI──▶│ arena       │  │
│  │ ingest   │        │ sqlite      │  │
│  │ MCP svr  │        │ graph       │  │
│  └────┬─────┘        └─────────────┘  │
│       │ stdio                          │
│       ▼                                │
│  MCP endpoint                          │
└────────────────────────────────────────┘
```

## Quick start

### As a binary

```bash
task binary
./bin/kiln serve /path/to/your/code
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

## Claude Code integration

### Binary mode

```json
{
  "mcpServers": {
    "mache": {
      "command": "kiln",
      "args": ["serve", "/path/to/code"]
    }
  }
}
```

### Container mode

```json
{
  "mcpServers": {
    "mache": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-v", "${workspaceFolder}:/source:ro",
        "-v", "kiln-cache:/data",
        "kiln", "/source"
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
just the kiln binary + musl libc + ca-certs. Signed with cosign, optionally
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

Apache-2.0 (same as mache and ley-line)
