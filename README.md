# LiteLLM API gateway (Docker Compose + Caddy)

Self-contained stack: **LiteLLM** as an OpenAI-compatible proxy, **Caddy** for TLS and reverse proxying, **Docker Compose** for orchestration. Suited to internal AI gateways where provider keys live in one place.

## Layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Production-oriented services, health checks, TLS ports |
| `docker-compose.override.yml` | Local dev: HTTP on port **8080**, relaxed default master key |
| `litellm-config.yaml` | Models, routing, logging |
| `Caddyfile` | Production TLS + upstream health-aware proxy to LiteLLM |
| `Caddyfile.dev` | Plain HTTP `:8080` for development |
| `.env.example` | Environment template (copy to `.env`) |
| `scripts/smoke-test.sh` | Quick `curl` against `/v1/models` |
| `scripts/caddy-hash-password.sh` | Bcrypt hash for optional Caddy `basic_auth` |

## Quick start (development)

1. Copy environment template and set at least a dev master key if you want it non-default:

   ```bash
   cp .env.example .env
   # edit .env — optional in dev; override file provides sk-dev-master-key-change-me if unset
   ```

2. Start the stack (Compose automatically merges `docker-compose.override.yml`):

   ```bash
   docker compose up -d
   ```

3. Sanity check:

   ```bash
   export LITELLM_MASTER_KEY="${LITELLM_MASTER_KEY:-sk-dev-master-key-change-me}"
   ./scripts/smoke-test.sh
   ```

   LiteLLM is also reachable directly at `http://127.0.0.1:4000` only if you publish port `4000` (not done by default in the base file). Through Caddy dev, use **`http://127.0.0.1:8080`**.

4. Example chat completion (requires a configured model and provider key):

   ```bash
   curl http://127.0.0.1:8080/v1/chat/completions \
     -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
     -H "Content-Type: application/json" \
     -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Hello"}]}'
   ```

## Production deploy

1. **Do not** ship `docker-compose.override.yml` to the server (or run Compose with an explicit base file only):

   ```bash
   docker compose -f docker-compose.yml up -d
   ```

2. Set strong `LITELLM_MASTER_KEY` and provider keys in `.env` (see `.env.example`).

3. Set `CADDY_DOMAIN` to your public hostname and `CADDY_EMAIL` for Let’s Encrypt. For private hostnames, consider DNS, TLS policy, or Caddy’s `tls` [directives](https://caddyserver.com/docs/caddyfile/directives/tls) as appropriate to your environment.

4. Trim `litellm-config.yaml` so you only declare models for providers you configured—some LiteLLM builds complain if a model references a missing API key.

## Security notes

- Treat `LITELLM_MASTER_KEY` like a root API key for the proxy; rotate it if leaked.
- `LITELLM_API_KEYS` (optional) is passed through for LiteLLM virtual-key / budget flows when your LiteLLM version and backing store support it.
- Optional edge **basic auth** in Caddy: generate a hash with `./scripts/caddy-hash-password.sh 'secret'` and add a `basic_auth` block inside the site block in `Caddyfile` (commented example included there).

## Adding Ollama (example)

1. Add a service and volume to `docker-compose.yml` (and attach it to `llm_net`):

   ```yaml
   ollama:
     image: ollama/ollama:latest
     restart: unless-stopped
     volumes:
       - ollama_data:/root/.ollama
     networks:
       - llm_net
   ```

   Plus a top-level `volumes: ollama_data:`.

2. Uncomment and adjust the Ollama `model_list` entry in `litellm-config.yaml`.

3. `docker compose exec ollama ollama pull llama3` (model name as you prefer), then restart LiteLLM.

## Observability and next steps

- LiteLLM logs JSON to stdout by default in this config (`json_logs: true`), suitable for log collectors.
- Health: LiteLLM exposes `/health/liveliness` and `/health/readiness`; Caddy uses liveness for upstream passive health checks in production.
- You can add Postgres, Redis, Prometheus, and Grafana in separate Compose files or services when you need persistence, queues, or dashboards.

## Commands used while authoring this layout

- `docker compose config` — validate merged Compose YAML (recommended after edits).

## License

Configuration in this folder is provided as a starting point for your infrastructure; apply your organization’s policies before production use.
