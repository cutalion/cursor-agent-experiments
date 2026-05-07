#!/usr/bin/env bash
# Helper to generate a bcrypt hash for BASIC_AUTH_HASH.
#   ./scripts/caddy-hash.sh
# Reads the password from stdin (no echo).
set -euo pipefail
exec docker run --rm -i caddy:2-alpine caddy hash-password
