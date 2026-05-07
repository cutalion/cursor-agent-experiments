# LiteLLM API Gateway Infrastructure

Self-contained Docker Compose infrastructure for a LiteLLM OpenAI-compatible API gateway behind Caddy. It is intended to work for local development first, then harden into a production deployment with HTTPS, basic auth, persistent LiteLLM state, and provider keys managed centrally.

## What Is Included

- LiteLLM proxy on port `4000`
- Caddy reverse proxy with automatic HTTPS for production
- Caddy development listener on `http://localhost:8080`
- Postgres persistence for LiteLLM keys, spend tracking, and UI state
- Optional Ollama service under the `local-models` Compose profile
- Environment template, helper scripts, and operational notes

## Files

- `docker-compose.yml` - production-oriented Compose stack
- `docker-compose.override.yml` - development overrides loaded automatically by Docker Compose
- `litellm/config.yaml` - LiteLLM model routing and runtime settings
- `caddy/Caddyfile` - production HTTPS reverse proxy with basic auth
- `caddy/Caddyfile.dev` - local HTTP reverse proxy without external TLS
- `.env.example` - environment template
- `scripts/bootstrap-env.sh` - creates `.env` with generated local secrets
- `scripts/check-config.sh` - validates Compose and Caddy configuration when Docker is available
- `scripts/smoke-test.sh` - checks LiteLLM health and model listing
- `docs/providers.md` - provider configuration examples
- `docs/operations.md` - production and maintenance guidance

## Local Quickstart

Create an environment file:

```sh
cp .env.example .env
```

Or generate local secrets:

```sh
sh scripts/bootstrap-env.sh
```

Start the development stack:

```sh
docker compose up -d
```

The development override uses `caddy/Caddyfile.dev`, so the gateway is available at:

- LiteLLM direct: `http://localhost:4000`
- Caddy gateway: `http://localhost:8080`

Check the gateway:

```sh
sh scripts/smoke-test.sh
```

List models manually:

```sh
curl -H "Authorization: Bearer sk-dev-master-key-change-me" \
  http://localhost:4000/v1/models
```

## Production Start

Create and edit `.env`:

```sh
cp .env.example .env
```

Set at least:

- `GATEWAY_DOMAIN`
- `ACME_EMAIL`
- `CADDY_HTTP_PORT=80`
- `CADDY_HTTPS_PORT=443`
- `CADDY_BASIC_AUTH_HASH`
- `LITELLM_MASTER_KEY`
- `LITELLM_UI_PASSWORD`
- `POSTGRES_PASSWORD`
- provider API keys such as `OPENAI_API_KEY`

Generate the Caddy basic auth hash:

```sh
docker run --rm caddy:2-alpine caddy hash-password --plaintext 'your-password'
```

Start only the production Compose file, without the development override:

```sh
docker compose -f docker-compose.yml up -d
```

Caddy will request and renew TLS certificates for `GATEWAY_DOMAIN`.

## Calling The Gateway

LiteLLM exposes an OpenAI-compatible API. Use `LITELLM_MASTER_KEY` or a LiteLLM virtual key:

```sh
curl https://ai-gateway.example.com/v1/chat/completions \
  -u "admin:your-caddy-password" \
  -H "Authorization: Bearer sk-your-master-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "messages": [{"role": "user", "content": "Say hello"}]
  }'
```

For internal service-to-service access, prefer LiteLLM virtual keys with budgets and model allow-lists over sharing the master key.

## Optional Local Models

Start Ollama alongside the gateway:

```sh
docker compose --profile local-models up -d
```

Pull a model into the Ollama container:

```sh
docker compose exec ollama ollama pull llama3.1
```

Then call LiteLLM with `model: "llama3-local"`.

## Validation

Run:

```sh
sh scripts/check-config.sh
```

This validates Docker Compose rendering and Caddy configuration when Docker is installed. `scripts/smoke-test.sh` validates a running gateway.
