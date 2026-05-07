#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <plain-text-password>" >&2
  exit 1
fi

docker run --rm caddy:2.8 caddy hash-password --plaintext "$1"
