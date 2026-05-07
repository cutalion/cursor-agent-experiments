#!/usr/bin/env bash
# Tear down the production stack (skips the dev override).
set -euo pipefail
cd "$(dirname "$0")/.."
exec docker compose -f docker-compose.yml "$@" down
