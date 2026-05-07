#!/usr/bin/env bash
# Internal helper sourced by prod-up.sh. Fails fast if obvious secrets
# look wrong (still default placeholder, or empty).
set -euo pipefail

# Load .env without leaking secrets to the surrounding shell.
set -a; . ./.env; set +a

fail() { echo "ENV ERROR: $*" >&2; exit 1; }

[[ -n "${LITELLM_MASTER_KEY:-}" ]] || fail "LITELLM_MASTER_KEY is empty"
[[ "$LITELLM_MASTER_KEY" != "sk-CHANGEME-master" ]] || fail "LITELLM_MASTER_KEY is still the placeholder — run ./scripts/gen-keys.sh"

if [[ -n "${DOMAIN:-}" && "$DOMAIN" == *".localhost" ]]; then
  echo "WARNING: DOMAIN=$DOMAIN is a .localhost address — Caddy can't get a real cert for that." >&2
fi

if [[ -n "${BASIC_AUTH_USER:-}" && -z "${BASIC_AUTH_HASH:-}" ]]; then
  fail "BASIC_AUTH_USER set but BASIC_AUTH_HASH is empty"
fi
