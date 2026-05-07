#!/usr/bin/env bash
# Tail logs for one or all services.
# Usage:
#   ./scripts/logs.sh              # all services
#   ./scripts/logs.sh litellm      # LiteLLM only
#   ./scripts/logs.sh caddy        # Caddy only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

SERVICE="${1:-}"
docker compose logs -f --tail=100 $SERVICE
