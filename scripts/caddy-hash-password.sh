#!/usr/bin/env bash
# Print a bcrypt hash suitable for Caddy `basic_auth` blocks.
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <plaintext-password>" >&2
  exit 1
fi
exec docker run --rm caddy:2-alpine caddy hash-password --plaintext "$1"
