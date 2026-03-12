#!/bin/sh
set -e

ARENA_PATH="${KILN_ARENA:-/data/arena.db}"
DATA_DIR="$(dirname "$ARENA_PATH")"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Pass all arguments through to mache serve.
# First positional arg is the data source (e.g. /source).
# Additional flags (--schema, etc.) pass through unchanged.
exec mache serve "$@"
