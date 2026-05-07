#!/usr/bin/env sh
set -eu

BASE_URL="${1:-http://localhost:8080}"
KEY="${LITELLM_MASTER_KEY:-}"

if [ -z "$KEY" ]; then
  echo "LITELLM_MASTER_KEY must be exported in your shell for smoke test." >&2
  exit 1
fi

echo "==> Health check"
curl -fsS "${BASE_URL}/health/readiness" >/dev/null
echo "OK"

echo "==> Models endpoint"
curl -fsS \
  -H "Authorization: Bearer ${KEY}" \
  "${BASE_URL}/v1/models"
echo
