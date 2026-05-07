#!/usr/bin/env bash
# Bring the stack up in development mode.
# - litellm exposed on http://localhost:4000
# - caddy   exposed on http://localhost:8080 (proxies to litellm)

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "No .env found — copying from .env.example. Edit it before going to prod." >&2
  cp .env.example .env
fi

# Includes docker-compose.override.yml automatically.
exec docker compose up -d --remove-orphans "$@"
