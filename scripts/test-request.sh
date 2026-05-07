#!/usr/bin/env bash
# Smoke-test the gateway with a tiny chat completion.
#
#   ./scripts/test-request.sh                       # hits dev (localhost:4000)
#   ./scripts/test-request.sh gpt-4o-mini           # pick a different model
#   GATEWAY_URL=https://gw.example.com \
#     ./scripts/test-request.sh claude-3-5-sonnet   # hit prod through Caddy

set -euo pipefail
cd "$(dirname "$0")/.."

MODEL="${1:-gpt-4o-mini}"
GATEWAY_URL="${GATEWAY_URL:-http://localhost:4000}"

if [[ -f .env ]]; then
  set -a; . ./.env; set +a
fi
KEY="${LITELLM_MASTER_KEY:-${API_KEY:-}}"
if [[ -z "$KEY" ]]; then
  echo "Set LITELLM_MASTER_KEY in .env or pass API_KEY=... in the environment." >&2
  exit 1
fi

set -x
curl -sS --fail-with-body \
  -H "Authorization: Bearer ${KEY}" \
  -H "Content-Type: application/json" \
  -d "{
        \"model\": \"${MODEL}\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Say hi in 5 words.\"}]
      }" \
  "${GATEWAY_URL%/}/v1/chat/completions" | jq . 2>/dev/null || true
