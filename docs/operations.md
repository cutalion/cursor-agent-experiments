# Operations Guide

## Security Checklist

- Replace every `change-me` value in `.env`.
- Use a long random `LITELLM_MASTER_KEY` beginning with `sk-`.
- Keep Caddy basic auth enabled on public deployments.
- Issue LiteLLM virtual keys to teams and services instead of sharing the master key.
- Restrict exposed ports with host firewall rules. LiteLLM is bound to `127.0.0.1` by default; Caddy is the public entrypoint.
- Store `.env` in a secret manager for production. It is intentionally ignored by git.

## Deployment Shape

For development, run:

```sh
docker compose up -d
```

For production, run only the base Compose file:

```sh
docker compose -f docker-compose.yml up -d
```

The production Caddyfile expects a DNS name in `GATEWAY_DOMAIN` and will request TLS certificates automatically.

## Health Checks

LiteLLM has a Compose health check against:

```text
http://localhost:4000/health/readiness
```

Caddy forwards health paths without basic auth:

```text
/health
/health/*
/_health
```

Use `scripts/smoke-test.sh` after deployment to verify the proxy is serving requests.

## Persistence And Backups

LiteLLM state is stored in the `postgres_data` Docker volume. Caddy certificates and state are stored in:

- `caddy_data`
- `caddy_config`

Back up these volumes before upgrades:

```sh
docker run --rm -v litellm-gateway_postgres_data:/data -v "$PWD:/backup" alpine \
  tar czf /backup/postgres_data.tgz -C /data .
```

For higher durability, replace the Compose Postgres service with a managed Postgres instance and set `DATABASE_URL` directly for LiteLLM.

## Logs

Follow service logs:

```sh
docker compose logs -f --tail=100 litellm caddy
```

LiteLLM is configured for JSON logs. Caddy logs to stdout in console format so container log drivers can collect it.

## Upgrades

Pull newer images:

```sh
docker compose pull
docker compose up -d
```

For production, use:

```sh
docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d
```

Pin image tags in `docker-compose.yml` before regulated or change-controlled deployments.

## Reliability Notes

- Services use `restart: unless-stopped`.
- Caddy waits for LiteLLM health before starting.
- LiteLLM waits for Postgres health before starting.
- LiteLLM retries upstream provider calls twice and uses a 180 second request timeout.
- The optional Ollama profile is isolated so cloud-provider deployments do not need local model resources.

## Rate Limits And Budgets

Use the LiteLLM admin UI or API to create virtual keys with:

- model allow-lists
- per-key budgets
- team ownership
- expiration dates

This keeps provider credentials centralized and gives internal teams scoped access to the gateway.
