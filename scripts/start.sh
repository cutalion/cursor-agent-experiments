#!/usr/bin/env bash
# Start the LiteLLM gateway stack.
# Usage:
#   ./scripts/start.sh            # development (with override)
#   ./scripts/start.sh prod       # production (no override)
#   ./scripts/start.sh ollama     # dev + Ollama
#   ./scripts/start.sh prod ollama  # production + Ollama

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

MODE="${1:-dev}"
WITH_OLLAMA=false
[[ "${2:-}" == "ollama" || "${1:-}" == "ollama" ]] && WITH_OLLAMA=true

if [[ ! -f .env ]]; then
  echo "⚠️  No .env file found. Copying .env.example → .env"
  cp .env.example .env
  echo "   Edit .env and set your API keys before continuing."
  exit 1
fi

COMPOSE_FILES="-f docker-compose.yml"

if [[ "$MODE" == "dev" ]]; then
  echo "▶  Starting in DEVELOPMENT mode (HTTP on :8080)"
  COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.override.yml"
else
  echo "▶  Starting in PRODUCTION mode (HTTPS on :443)"
fi

if $WITH_OLLAMA; then
  echo "   + Ollama local LLM service enabled"
  COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.ollama.yml"
fi

docker compose $COMPOSE_FILES up -d --remove-orphans

echo ""
echo "✅  Stack is up."
if [[ "$MODE" == "dev" ]]; then
  echo "   LiteLLM direct:  http://localhost:4000"
  echo "   Via Caddy (dev): http://localhost:8080"
  echo "   UI (if enabled): http://localhost:4000/ui"
else
  echo "   Gateway: https://$(grep CADDY_DOMAIN .env | cut -d= -f2 | head -1)"
fi
echo ""
echo "   Run './scripts/health.sh' to verify all services."
