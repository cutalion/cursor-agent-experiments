#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
TEMPLATE_FILE="$ROOT_DIR/.env.example"

if [ -f "$ENV_FILE" ]; then
  echo ".env already exists; refusing to overwrite it."
  exit 0
fi

cp "$TEMPLATE_FILE" "$ENV_FILE"

random_hex() {
  openssl rand -hex "${1:-32}"
}

MASTER_KEY="sk-$(random_hex 32)"
UI_PASSWORD="$(random_hex 24)"
POSTGRES_PASSWORD="$(random_hex 24)"
BASIC_PASSWORD="$(random_hex 16)"
BASIC_HASH=""

if command -v docker >/dev/null 2>&1; then
  BASIC_HASH="$(docker run --rm caddy:2-alpine caddy hash-password --plaintext "$BASIC_PASSWORD" 2>/dev/null || true)"
fi

python3 - "$ENV_FILE" "$MASTER_KEY" "$UI_PASSWORD" "$POSTGRES_PASSWORD" "$BASIC_HASH" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
replacements = {
    "sk-change-me-to-a-long-random-secret": sys.argv[2],
    "change-me-to-a-long-random-password": sys.argv[3],
    "change-me-to-a-long-random-db-password": sys.argv[4],
}
if sys.argv[5]:
    replacements["replace-with-caddy-bcrypt-hash"] = sys.argv[5]

for old, new in replacements.items():
    text = text.replace(old, new)

path.write_text(text)
PY

echo "Created .env with generated LiteLLM and Postgres secrets."
if [ -n "$BASIC_HASH" ]; then
  echo "Generated Caddy basic auth for user 'admin'. Password: $BASIC_PASSWORD"
  echo "Store that password securely; it is not written to .env."
else
  echo "Docker was not available, so CADDY_BASIC_AUTH_HASH still needs to be generated."
  echo "Run: docker run --rm caddy:2-alpine caddy hash-password --plaintext 'your-password'"
fi
