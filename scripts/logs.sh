#!/usr/bin/env bash
# Tail logs for one or all services. Examples:
#   ./scripts/logs.sh              # all services
#   ./scripts/logs.sh litellm      # just litellm
set -euo pipefail
cd "$(dirname "$0")/.."
exec docker compose logs -f --tail=200 "$@"
