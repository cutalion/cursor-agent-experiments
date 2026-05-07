#!/usr/bin/env bash
# Call the gateway OpenAI-compatible /v1/models endpoint (expects LITELLM_MASTER_KEY in env).
set -euo pipefail
BASE_URL="${LITELLM_BASE_URL:-http://127.0.0.1:8080}"
KEY="${LITELLM_MASTER_KEY:-sk-dev-master-key-change-me}"
curl -fsS -H "Authorization: Bearer ${KEY}" "${BASE_URL}/v1/models" | head -c 2000
echo
