#!/usr/bin/env bash
# Verify all services are healthy and the LiteLLM API is reachable.
# Usage: ./scripts/health.sh [--prod]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

PROD=false
[[ "${1:-}" == "--prod" ]] && PROD=true

LITELLM_URL="http://localhost:4000"
GATEWAY_URL="http://localhost:8080"
$PROD && GATEWAY_URL="https://$(grep CADDY_DOMAIN .env 2>/dev/null | cut -d= -f2 | head -1)"

echo "=== Docker service health ==="
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== LiteLLM health endpoints ==="

check() {
  local label="$1"
  local url="$2"
  local http_code
  http_code=$(curl -sf -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  if [[ "$http_code" =~ ^2 ]]; then
    echo "  ✅  $label → $url ($http_code)"
  else
    echo "  ❌  $label → $url ($http_code)"
  fi
}

check "LiteLLM liveliness" "$LITELLM_URL/health/liveliness"
check "LiteLLM readiness"  "$LITELLM_URL/health/readiness"
check "LiteLLM models"     "$LITELLM_URL/v1/models"
check "Gateway"            "$GATEWAY_URL/v1/models"

echo ""
echo "=== Quick chat smoke-test (via gateway) ==="
MASTER_KEY="${LITELLM_MASTER_KEY:-$(grep LITELLM_MASTER_KEY .env 2>/dev/null | cut -d= -f2 | head -1)}"

if [[ -z "$MASTER_KEY" ]]; then
  echo "  ⚠️  LITELLM_MASTER_KEY not set — skipping API smoke-test."
else
  RESP=$(curl -sf -X POST "$GATEWAY_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $MASTER_KEY" \
    -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Reply with OK"}],"max_tokens":5}' \
    2>/dev/null || echo "")
  if echo "$RESP" | grep -q '"content"'; then
    echo "  ✅  Chat completion returned a response."
  else
    echo "  ⚠️  Chat completion did not return expected response (provider key may be missing)."
    echo "      Raw response: $RESP"
  fi
fi
