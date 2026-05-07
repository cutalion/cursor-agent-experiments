# LiteLLM Gateway Infrastructure

Self-contained infrastructure for an internal AI API gateway based on LiteLLM, Caddy, and Docker Compose.

## What This Includes

- Production-oriented Compose stack with:
  - `litellm` OpenAI-compatible API gateway
  - `caddy` reverse proxy with automatic HTTPS
  - Optional `ollama` local model provider (profile-based)
- Development override config for local iteration
- Caddy security defaults and optional basic auth
- LiteLLM routing config for OpenAI + Ollama
- Environment templates and helper scripts

## Files

- `docker-compose.yml`: production-friendly base services
- `docker-compose.override.yml`: local/dev behavior overrides
- `Caddyfile`: HTTPS domain gateway config
- `Caddyfile.dev`: local HTTP gateway config
- `litellm-config.yaml`: provider/model routing and LiteLLM settings
- `.env.example`: production-like env template
- `.env.dev.example`: local env template
- `scripts/hash-password.sh`: generate Caddy bcrypt hash
- `scripts/dev-up.sh`: start local stack (uses override)
- `scripts/prod-up.sh`: start base stack only
- `scripts/smoke-test.sh`: readiness + model list checks

## Quickstart (Development)

1. Prepare environment:

   ```bash
   cp .env.dev.example .env
   ./scripts/hash-password.sh "change-me-now"
   # paste hash into CADDY_BASICAUTH_HASH in .env
   ```

2. Start:

   ```bash
   ./scripts/dev-up.sh
   ```

3. Verify:

   ```bash
   export LITELLM_MASTER_KEY='sk-dev-master-key-change-me'
   ./scripts/smoke-test.sh http://localhost:8080
   ```

## Production Notes

- Copy `.env.example` to `.env` and set strong keys:
  - `LITELLM_MASTER_KEY`
  - `LITELLM_SALT_KEY`
- Set `GATEWAY_DOMAIN` + `ACME_EMAIL` for automatic TLS.
- Keep `.env` out of source control.
- Prefer running behind firewall/security groups and allow only needed ports.

## Optional Local LLM (Ollama)

Enable local provider in addition to cloud providers:

```bash
docker compose --profile local-llm up -d
```

`litellm-config.yaml` already includes `ollama/llama3` and reads `OLLAMA_BASE_URL`.

## Useful Commands

```bash
docker compose config
docker compose logs -f litellm caddy
docker compose down
docker compose down -v
```
