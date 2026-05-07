#!/usr/bin/env bash
# Generate LITELLM_MASTER_KEY and LITELLM_SALT_KEY values.
# Pipe straight into your .env, or copy/paste the lines we print.
#
#   ./scripts/gen-keys.sh
#   ./scripts/gen-keys.sh >> .env

set -euo pipefail

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required (install via apt/brew)." >&2
  exit 1
fi

cat <<EOF
LITELLM_MASTER_KEY=sk-$(openssl rand -hex 24)
LITELLM_SALT_KEY=sk-$(openssl rand -hex 24)
EOF
