# LiteLLM AI API Gateway

A small, modular infrastructure that puts a single OpenAI-compatible
endpoint in front of every LLM your team uses — cloud (OpenAI,
Anthropic, Groq…) and self-hosted (Ollama, TGI…) — so apps and
people don't have to juggle provider credentials.

```
┌──────────┐    HTTPS    ┌────────┐   HTTP    ┌──────────┐    HTTPS   ┌──────────────┐
│ clients  │ ──────────► │ Caddy  │ ────────► │ LiteLLM  │ ────────►  │ providers    │
│ (apps,   │ <────────── │ :443   │ <──────── │ :4000    │ <────────  │ OpenAI,      │
│  curl)   │             │  TLS   │           │ proxy    │            │ Anthropic,   │
└──────────┘             └────────┘           └──────────┘            │ Ollama, …    │
                                                                      └──────────────┘
```

* **LiteLLM** — universal OpenAI-compatible proxy + virtual key
  management.
* **Caddy** — TLS termination, automatic Let's Encrypt certs, optional
  basic-auth, security headers.
* **Docker Compose** — one base file, one dev override, opt-in overlays
  for Postgres and Ollama.

---

## Repository layout

```
.
├── docker-compose.yml             # base / production
├── docker-compose.override.yml    # dev override (auto-loaded)
├── litellm-config.yaml            # model catalogue + LiteLLM settings
├── Caddyfile                      # production reverse proxy + TLS
├── Caddyfile.dev                  # plain-HTTP dev reverse proxy
├── .env.example                   # copy to .env and fill in
├── compose/
│   ├── postgres.yml               # opt-in DB for virtual keys / usage
│   └── ollama.yml                 # opt-in self-hosted models
├── scripts/                       # gen-keys, dev/prod up/down, smoke test
└── Makefile                       # `make help` for shortcuts
```

---

## Requirements

* Docker Engine ≥ 24
* Docker Compose v2 ≥ **2.24** (we use the `!override` tag in
  `docker-compose.override.yml`). Check with `docker compose version`.
* `openssl` for `scripts/gen-keys.sh`
* `curl` + `jq` for `scripts/test-request.sh` (optional)

---

## Quickstart (development)

```bash
# 1. Generate secrets and seed your env file
./scripts/gen-keys.sh > .env.tmp
cp .env.example .env
cat .env.tmp >> .env && rm .env.tmp     # or just paste the lines

# 2. Add at least one upstream provider key, e.g. OPENAI_API_KEY
$EDITOR .env

# 3. Bring it up
make dev      # or: ./scripts/dev-up.sh

# 4. Smoke test through the dev gateway
make test     # hits http://localhost:4000/v1/chat/completions
# or through Caddy on 8080:
GATEWAY_URL=http://localhost:8080 make test
```

You should get a JSON chat completion back. Logs:

```bash
make logs              # all
make logs s=litellm    # one service
```

Tear it down with `make dev-down` (add `--volumes` to wipe Caddy state).

---

## Production deploy

1. **DNS**: point `gw.example.com` (or whatever you pick) at the host.
2. **Firewall**: open inbound 80/tcp and 443/tcp+udp.
3. **`.env`**:
   ```bash
   cp .env.example .env
   ./scripts/gen-keys.sh >> .env
   $EDITOR .env       # set DOMAIN, ACME_EMAIL, provider keys, …
   ```
4. **Bring it up** (no dev override):
   ```bash
   make prod          # or: ./scripts/prod-up.sh
   ```
5. **Verify**:
   ```bash
   curl -fsS https://$DOMAIN/health/liveliness
   GATEWAY_URL=https://$DOMAIN make test
   ```

The first request takes a few seconds while Caddy provisions the
certificate. After that everything is cached in the `caddy_data`
volume.

### Optional gateway-level basic auth

LiteLLM already enforces API keys, but you can stack a Caddy
basic-auth prompt in front of the whole API:

```bash
./scripts/caddy-hash.sh    # type your password, copy the bcrypt hash
# Paste into .env:
BASIC_AUTH_USER=internal
BASIC_AUTH_HASH=<paste here>
```

Then uncomment the `basic_auth { ... }` block in `Caddyfile` and run
`docker compose restart caddy` (or `make prod`).

---

## Issuing virtual keys to teammates

Don't share `LITELLM_MASTER_KEY`. Spin up a Postgres-backed deploy and
mint per-team keys with budgets and model allow-lists.

```bash
# Bring the stack up with the Postgres overlay
make prod-pg          # or: ./scripts/prod-up.sh -f compose/postgres.yml

# Issue a virtual key (any HTTP client works)
curl -fsS -X POST https://$DOMAIN/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
        "team_id": "data-team",
        "models": ["gpt-4o-mini", "claude-3-5-sonnet"],
        "max_budget": 50,
        "duration": "30d"
      }'
```

Hand the returned `sk-…` key to the user. Revoke at
`/key/delete` or via the admin UI at `/ui` (login with the master
key).

---

## Adding a self-hosted model (Ollama)

```bash
make prod-pg-ollama       # postgres + ollama overlays
docker exec -it ollama ollama pull llama3
```

Edit `litellm-config.yaml` and uncomment the `ollama-llama3` block,
then:

```bash
docker compose restart litellm
GATEWAY_URL=https://$DOMAIN make test m=ollama-llama3
```

GPU? Uncomment the `deploy.resources.reservations.devices` block in
`compose/ollama.yml` and install nvidia-container-toolkit on the host.

---

## Adding new cloud providers

1. Drop a new entry into `model_list:` in `litellm-config.yaml`.
2. Add the matching `*_API_KEY` to `.env` (and `.env.example`).
3. `docker compose restart litellm`.

LiteLLM supports 100+ providers — see
[the docs](https://docs.litellm.ai/docs/providers) for the exact
`model:` slug to use.

---

## Operations cheatsheet

| Task                            | Command                              |
| ------------------------------- | ------------------------------------ |
| Tail logs                       | `make logs` / `make logs s=litellm`  |
| Restart one service             | `make restart s=litellm`             |
| Pull newer images               | `make pull && make prod`             |
| Inspect merged compose config   | `make config`                        |
| Wipe everything (incl. volumes) | `./scripts/prod-down.sh --volumes`   |
| Generate fresh master/salt keys | `make keys`                          |
| Generate basic-auth hash        | `make hash`                          |

---

## Security notes

* `.env` is gitignored; never commit it. CI should inject these.
* `LITELLM_MASTER_KEY` has full admin powers. Treat it like a root
  password — keep it out of client apps and prefer virtual keys.
* In production the LiteLLM port is **not** published to the host.
  Caddy is the only thing exposed.
* Caddy adds HSTS / `X-Content-Type-Options` / `X-Frame-Options` /
  Referrer-Policy by default. Override in `Caddyfile` if you have an
  edge CDN that already sets them.
* The Postgres overlay encrypts virtual keys at rest using
  `LITELLM_SALT_KEY`. Rotate by re-issuing keys, **not** by changing
  the salt — the old keys would become unreadable.

---

## Future expansion

The compose layout is designed to grow without rewrites:

| Want…                              | Add…                                            |
| ---------------------------------- | ----------------------------------------------- |
| Persistent virtual keys / usage    | `compose/postgres.yml` (provided)              |
| Self-hosted open-weights models    | `compose/ollama.yml` (provided)                |
| Response caching, rate-limit store | a `compose/redis.yml` overlay + `cache: true`   |
| Metrics                            | LiteLLM exposes `/metrics` (Prometheus)         |
| Tracing                            | `success_callback: ["langfuse"]` in config      |
| Alternative ingress                | swap `Caddyfile` for Traefik/Nginx; everything |
|                                    | downstream stays the same                       |

---

## Troubleshooting

* **`!override` errors on `docker compose up`** — your Compose is
  older than 2.24. Either upgrade, or run prod-style:
  `docker compose -f docker-compose.yml up -d` (no dev override).
* **Caddy keeps retrying ACME** — DNS not yet propagated, or 80/443
  blocked. Use `:8080` (dev) until DNS is ready.
* **`Error: invalid API Key`** — the `Authorization` header must be
  `Bearer <LITELLM_MASTER_KEY>` or a virtual key starting with `sk-`.
* **`model not found`** — the alias in your request must match a
  `model_name` in `litellm-config.yaml`. List them:
  ```bash
  curl -fsS -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
    https://$DOMAIN/v1/models | jq .
  ```
