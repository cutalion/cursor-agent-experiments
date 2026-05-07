#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to validate the Compose and Caddy configuration."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "docker compose is required to validate this project."
  exit 1
fi

docker compose --env-file .env.example config >/dev/null
docker compose --env-file .env.example -f docker-compose.yml config >/dev/null

docker run --rm \
  -e GATEWAY_DOMAIN=localhost \
  -e ACME_EMAIL=dev@example.local \
  -e CADDY_BASIC_AUTH_USER=admin \
  -e CADDY_BASIC_AUTH_HASH='$2a$10$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36UMshK4OqA7cMq7S4Fj6O2' \
  -v "$ROOT_DIR/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" \
  caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

docker run --rm \
  -v "$ROOT_DIR/caddy/Caddyfile.dev:/etc/caddy/Caddyfile:ro" \
  caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

python3 - <<'PY'
import pathlib

config = pathlib.Path("litellm/config.yaml").read_text()
required = [
    "model_list:",
    "general_settings:",
    "litellm_settings:",
    "router_settings:",
    "os.environ/LITELLM_MASTER_KEY",
]
missing = [item for item in required if item not in config]
if missing:
    raise SystemExit(f"LiteLLM config is missing expected entries: {missing}")
PY

echo "Configuration validation passed."
