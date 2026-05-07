#!/usr/bin/env bash
# Bring the stack up in production mode (no dev override applied).
# Caddy will request a real cert for $DOMAIN — make sure DNS is pointed
# at this host and ports 80/443 are reachable from the public internet.
#
# Usage:
#   ./scripts/prod-up.sh                          # base only
#   ./scripts/prod-up.sh -f compose/postgres.yml  # base + postgres
#   ./scripts/prod-up.sh -f compose/postgres.yml -f compose/ollama.yml

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "ERROR: .env is required for production. Copy .env.example and fill it in." >&2
  exit 1
fi

# Sanity-check critical secrets.
. ./scripts/_check-env.sh

exec docker compose -f docker-compose.yml "$@" up -d --remove-orphans
