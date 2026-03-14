# CLAUDE.md

Kiln packages mache (Go) + ley-line (Rust) into a single distributable
artifact. It is glue — the logic lives in mache and ley-line.

## What kiln is

A build/packaging repo. Contains:
- `Dockerfile` — multi-stage dev build
- `Dockerfile.release` — slim image from pre-built binary
- `melange.yaml` — APK package definition (builds the fat binary)
- `apko.yaml` — distroless OCI image assembly
- `Taskfile.yml` — orchestrates all build modes (uses [Task](https://taskfile.dev))
- `scripts/entrypoint.sh` — container entrypoint
- `.github/workflows/` — CI + release pipelines
- `.envrc` — direnv config

## What kiln is NOT

- Not a Go module (no go.mod)
- Not a Rust crate (no Cargo.toml)
- No application logic — that's mache and ley-line

## Sibling directories

Kiln expects mache and ley-line as siblings:
```
parent/
  mache/      → Go, schema + ingest + MCP server
  ley-line/   → Rust, arena + SQLite + FFI staticlib
  kiln/       → this repo, build + packaging
```

## Build commands

```bash
task binary       # Fat binary: Go links Rust staticlib via CGO
task image        # Docker image (dev)
task apk          # melange + apko distroless image (release)
task sign         # cosign signature
task test         # Smoke test
```

## Key details

- The fat binary IS mache's binary, just compiled with ley-line linked in.
  The output is named `mache` and it's `go build .` in the mache dir.
- CGO_LDFLAGS and CGO_CFLAGS are the critical glue — they point Go's linker
  at ley-line's `libleyline_fs.a` staticlib.
- On Linux, the binary can be fully static via musl. On macOS it uses the
  native toolchain.
- apko images are reproducible (same input = same hash) and distroless
  (no shell, no package manager).
