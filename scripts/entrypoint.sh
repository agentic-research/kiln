#!/bin/sh
set -e

ARENA_PATH="${KILN_ARENA:-/data/default.arena}"
CTRL_PATH="${KILN_CTRL:-/data/default.ctrl}"
ARENA_SIZE="${KILN_ARENA_SIZE:-64}"
DATA_DIR="$(dirname "$ARENA_PATH")"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# In stdio mode, skip leyline daemon — stdio clients expect immediate handshake.
STDIO_MODE=false
for arg in "$@"; do
  case "$arg" in --stdio) STDIO_MODE=true; break;; esac
done

# Start ley-line daemon in background (provides UDS control socket for LSP etc.)
if [ "$STDIO_MODE" = false ] && command -v leyline >/dev/null 2>&1; then
  echo "Starting leyline daemon (arena=$ARENA_PATH, ctrl=$CTRL_PATH)"
  leyline serve \
    --arena "$ARENA_PATH" \
    --arena-size-mib "$ARENA_SIZE" \
    --control "$CTRL_PATH" \
    --mount /data/mount &
  LEYLINE_PID=$!

  # Export socket path for mache's auto-enrichment discovery
  export LEYLINE_SOCKET="${CTRL_PATH}.sock"

  # Give daemon a moment to create the socket
  sleep 1

  # Ensure leyline is cleaned up on exit
  trap "kill $LEYLINE_PID 2>/dev/null; wait $LEYLINE_PID 2>/dev/null" EXIT
fi

# Pass all arguments through to mache serve.
# First positional arg is the data source (e.g. /source).
# Additional flags (--schema, etc.) pass through unchanged.
exec mache serve "$@"
