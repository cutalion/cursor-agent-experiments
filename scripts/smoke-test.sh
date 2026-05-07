#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://localhost:4000}"
API_KEY="${LITELLM_MASTER_KEY:-sk-dev-master-key-change-me}"

echo "Checking LiteLLM health at $BASE_URL ..."
curl --fail --silent --show-error "$BASE_URL/health/readiness" >/dev/null

echo "Checking model listing ..."
curl --fail --silent --show-error \
  -H "Authorization: Bearer $API_KEY" \
  "$BASE_URL/v1/models" >/dev/null

echo "Smoke test passed."
