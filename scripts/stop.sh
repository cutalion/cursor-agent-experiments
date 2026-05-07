#!/usr/bin/env bash
# Stop the gateway stack without removing volumes.
# Usage: ./scripts/stop.sh [--volumes]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

EXTRA=""
[[ "${1:-}" == "--volumes" ]] && EXTRA="--volumes"

docker compose down $EXTRA

echo "✅  Stack stopped."
[[ -n "$EXTRA" ]] && echo "   Volumes removed."
