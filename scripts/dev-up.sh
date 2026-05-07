#!/usr/bin/env sh
set -eu

if [ ! -f .env ]; then
  echo "Missing .env file. Copy .env.dev.example to .env first." >&2
  exit 1
fi

docker compose up -d --build
docker compose ps
