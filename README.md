# LiteLLM AI Gateway

A production-friendly and development-friendly AI API gateway built on **LiteLLM**, **Caddy**, and **Docker Compose**. It exposes a single OpenAI-compatible endpoint that routes to multiple AI providers (OpenAI, Anthropic, Groq, Ollama, etc.) while managing API keys, access control, and TLS centrally.

---

## Architecture

```
Client
  │
  ▼
Caddy (TLS termination, security headers, rate limiting)
  │
  ▼
LiteLLM (routing, virtual keys, spend tracking, retries)
  │
  ├─▶ OpenAI
  ├─▶ Anthropic
  ├─▶ Groq
  ├─▶ Ollama (optional, local)
  └─▶ Azure OpenAI (optional)
```

---

## File Layout

```
.
├── docker-compose.yml           # Production service definitions
├── docker-compose.override.yml  # Dev overrides (auto-applied by Docker Compose)
├── docker-compose.ollama.yml    # Optional Ollama extension
├── litellm-config.yaml          # LiteLLM model routing config
├── litellm-config.ollama.yaml   # LiteLLM config with Ollama models
├── Caddyfile                    # Production Caddy (HTTPS, Let's Encrypt)
├── Caddyfile.dev                # Dev Caddy (plain HTTP on :8080)
├── .env.example                 # Environment variable template
└── scripts/
    ├── start.sh                 # Start stack (dev or prod)
    ├── stop.sh                  # Stop stack
    ├── logs.sh                  # Tail service logs
    ├── health.sh                # Health-check all services
    └── keygen.sh                # Generate virtual API keys
```

---

## Quickstart (Development)

```bash
# 1. Copy and edit environment variables
cp .env.example .env
$EDITOR .env   # set at least LITELLM_MASTER_KEY and one provider key

# 2. Start in dev mode (HTTP only, debug logging)
./scripts/start.sh

# 3. Verify everything is healthy
./scripts/health.sh

# 4. Send a test request
curl http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Hello!"}]}'
```

Dev endpoints:
| Service | URL |
|---------|-----|
| LiteLLM (direct) | http://localhost:4000 |
| LiteLLM UI | http://localhost:4000/ui |
| Via Caddy (dev) | http://localhost:8080 |

---

## Production Deployment

```bash
# 1. Edit .env — set CADDY_DOMAIN to your real domain
cp .env.example .env
$EDITOR .env

# 2. Point your DNS A record to this server's public IP

# 3. Start in production mode (HTTPS, Let's Encrypt TLS)
./scripts/start.sh prod

# 4. Verify
./scripts/health.sh --prod
```

Caddy will automatically obtain and renew a TLS certificate for `CADDY_DOMAIN`.

---

## Adding Local LLM Support (Ollama)

```bash
# Start with Ollama enabled
./scripts/start.sh dev ollama

# Pull a model inside the container
docker compose exec ollama ollama pull llama3

# Use it through the gateway
curl http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3","messages":[{"role":"user","content":"Hello!"}]}'
```

---

## Virtual API Keys

Instead of sharing your master key, issue scoped virtual keys per team or service:

```bash
# Generate a key for a team (optional spend cap in USD)
./scripts/keygen.sh my-team 10.00

# The returned key is a standard Bearer token
curl http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer sk-..." \
  ...
```

Virtual keys support:
- Per-team or per-user spend budgets
- Model allow/deny lists
- Rate limits

Requires `DATABASE_URL` (Postgres) to be set for persistence across restarts.

---

## Configuration

### Adding a new model

Edit `litellm-config.yaml` and add an entry to `model_list`:

```yaml
- model_name: my-model-alias   # name clients will use
  litellm_params:
    model: groq/llama3-8b-8192
    api_key: os.environ/GROQ_API_KEY
```

Restart LiteLLM to apply: `docker compose restart litellm`

### Routing strategies

Set `router_settings.routing_strategy` in `litellm-config.yaml`:

| Value | Behaviour |
|-------|-----------|
| `simple-shuffle` | Random load balancing |
| `latency-based-routing` | Prefer the fastest model |
| `usage-based-routing-v2` | Prefer least-loaded (default) |

---

## Observability

### Logs

```bash
./scripts/logs.sh            # all services
./scripts/logs.sh litellm    # LiteLLM only
./scripts/logs.sh caddy      # Caddy access log
```

### Prometheus metrics

LiteLLM exposes Prometheus metrics at `/metrics`. To scrape them, add to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: litellm
    static_configs:
      - targets: ["litellm:4000"]
```

### Langfuse / other callbacks

Uncomment the `success_callback` line in `litellm-config.yaml` and set the relevant environment variables in `.env`.

---

## Expanding the Stack

### Add Postgres (persistent key management + spend tracking)

```yaml
# In docker-compose.override.yml or a new docker-compose.postgres.yml
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: litellm
      POSTGRES_PASSWORD: litellm
      POSTGRES_DB: litellm
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - gateway
```

Then set `DATABASE_URL=postgresql://litellm:litellm@postgres:5432/litellm` in `.env`.

### Add Redis (caching + distributed rate limiting)

```yaml
  redis:
    image: redis:7-alpine
    networks:
      - gateway
```

Then set `REDIS_URL=redis://redis:6379` in `.env`.

---

## Security Checklist

- [ ] Change `LITELLM_MASTER_KEY` to a long random value (`openssl rand -hex 32`)
- [ ] Never commit `.env` to version control (it's in `.gitignore`)
- [ ] In production, restrict access to port 4000 at the firewall level (only Caddy needs it)
- [ ] Rotate virtual API keys periodically
- [ ] Review the wildcard model pass-through in `litellm-config.yaml` — remove it to allow-list models explicitly
