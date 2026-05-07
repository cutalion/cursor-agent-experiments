#!/usr/bin/env sh
set -eu

if [ ! -f .env ]; then
  echo "Missing .env file. Copy .env.example to .env first." >&2
  exit 1
fi

docker compose -f docker-compose.yml up -d
docker compose -f docker-compose.yml ps
