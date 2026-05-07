#!/usr/bin/env bash
# Generate a virtual API key for a user/team via the LiteLLM admin API.
# Requires the stack to be running.
# Usage: ./scripts/keygen.sh <team_id> [spend_limit_usd]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

TEAM_ID="${1:?Usage: $0 <team_id> [max_budget_usd]}"
MAX_BUDGET="${2:-}"

LITELLM_URL="http://localhost:4000"
MASTER_KEY="${LITELLM_MASTER_KEY:-$(grep LITELLM_MASTER_KEY .env 2>/dev/null | cut -d= -f2 | head -1)}"

if [[ -z "$MASTER_KEY" ]]; then
  echo "❌  LITELLM_MASTER_KEY is not set."
  exit 1
fi

BODY="{\"team_id\": \"$TEAM_ID\""
[[ -n "$MAX_BUDGET" ]] && BODY="$BODY, \"max_budget\": $MAX_BUDGET"
BODY="$BODY}"

RESPONSE=$(curl -sf -X POST "$LITELLM_URL/key/generate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d "$BODY")

echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

KEY=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('key',''))" 2>/dev/null || echo "")
if [[ -n "$KEY" ]]; then
  echo ""
  echo "✅  Virtual key for '$TEAM_ID': $KEY"
fi
