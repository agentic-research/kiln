# kiln — where you fire a mache
#
# Multi-stage build: Rust (ley-line) → Go (mache + FFI link) → slim runtime
#
# Build context expects sibling dirs:
#   docker build -f kiln/Dockerfile -t kiln ..
#   (from the parent dir containing both mache/ and ley-line/)

# ── Stage 1: Build ley-line staticlib ────────────────────────────────
FROM rust:1.82-bookworm AS rust-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build/ley-line
COPY ley-line/rs/ ./rs/

WORKDIR /build/ley-line/rs
RUN cargo build --release --lib -p leyline-fs \
    && cargo build --release --lib -p leyline-sign

# Produce the static library and C header
RUN cp target/release/libleyline_fs.a /build/ \
    && cp target/release/libleyline_sign.a /build/ 2>/dev/null || true

# If cbindgen header exists, copy it; otherwise the one in mache's vendor wins
RUN if [ -f crates/fs/include/leyline_fs.h ]; then \
      cp crates/fs/include/leyline_fs.h /build/; \
    fi

# ── Stage 2: Build mache with ley-line linked ───────────────────────
FROM golang:1.23-bookworm AS go-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc libc6-dev libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build/mache
COPY mache/ ./

# Bring in ley-line artifacts from rust stage
COPY --from=rust-builder /build/libleyline_fs.a /usr/local/lib/
COPY --from=rust-builder /build/libleyline_sign.a /usr/local/lib/
COPY --from=rust-builder /build/leyline_fs.h /usr/local/include/

# Build mache, linking the ley-line staticlib
# CGO flags point at the ley-line artifacts
ENV CGO_ENABLED=1
ENV CGO_LDFLAGS="-L/usr/local/lib -lleyline_fs -lm -ldl -lpthread"
ENV CGO_CFLAGS="-I/usr/local/include"

RUN go build -o /mache .

# ── Stage 3: Slim runtime ───────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=go-builder /mache /usr/local/bin/mache
COPY kiln/scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Persistent cache for arena and projected databases
VOLUME /data

# User source code (bind-mounted read-only)
VOLUME /source

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
