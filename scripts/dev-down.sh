#!/usr/bin/env bash
# Tear down the dev stack. Pass --volumes to also wipe Caddy/Postgres/Ollama data.
set -euo pipefail
cd "$(dirname "$0")/.."
exec docker compose down "$@"
