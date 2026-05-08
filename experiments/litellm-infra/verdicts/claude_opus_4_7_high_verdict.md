# LiteLLM Infrastructure Experiment Verdict: claude-opus-4-7-high

## Final Ranking

1. `exp-gpt-5.5-high`
2. `exp-claude-opus-4-7-high`
3. `exp-composer-2`
4. `exp-claude-4.6-sonnet-medium-thinking`
5. `exp-auto`
6. `exp-gemini-3.1-pro`

## Best Setup: `exp-gpt-5.5-high`

`exp-gpt-5.5-high` is the strongest overall baseline. It is not the largest or most feature-rich branch, but it is the only one that combines a safe production boundary, fail-fast configuration, hardened Caddy defaults, and a workable onboarding path with a generated-secret bootstrap and a smoke test. The cost of those choices is moderate: it ships less optional infrastructure (no profiled Postgres or Redis, no log-rotation block) than `exp-claude-opus-4-7-high`. That trade-off is worth it because the things it omits are easy to add, while permissive production defaults in the larger setups are easy to ship by accident.

Concrete evidence:

- `exp-gpt-5.5-high:docker-compose.yml` requires `LITELLM_MASTER_KEY` and `GATEWAY_DOMAIN` with the Compose `:?` guard, so a broken `.env` aborts at `docker compose up` instead of running with insecure defaults. LiteLLM is `expose: "4000"` only — Caddy on `80/443` is the sole public surface in the production file.
- `exp-gpt-5.5-high:Caddyfile` disables the Caddy admin endpoint, sets HSTS / `X-Content-Type-Options` / `X-Frame-Options` / `Referrer-Policy` / `Permissions-Policy` / `-Server`, enables compression, and gives `reverse_proxy` upstream health probing.
- `exp-gpt-5.5-high:docker-compose.override.yml` keeps direct LiteLLM exposure (`${DEV_LITELLM_PORT:-4000}:4000`) and the plain-HTTP Caddy port strictly in the dev-only override.
- `exp-gpt-5.5-high:litellm-config.yaml` sets `telemetry: false`, `set_verbose: false`, `redact_user_api_key_info: true`, `drop_params: true`, retries, allowed-fails, and cooldown.
- `exp-gpt-5.5-high:scripts/bootstrap-env.sh` generates **both** master and salt keys, so users do not invent their own secrets.
- `exp-gpt-5.5-high:scripts/smoke-test.sh` checks liveness and authenticated `/v1/models`.
- `exp-gpt-5.5-high:Makefile` has dev / prod / ollama / smoke / caddy-hash targets.
- `exp-gpt-5.5-high:examples/Caddyfile.basic-auth` provides a drop-in hardened reverse-proxy with HSTS plus basic auth.

The honest gaps are: it pins to `ghcr.io/berriai/litellm:latest` rather than an immutable digest or a stable tag, the production override uses the newer Compose `!override` tag (requires up-to-date Compose v2), and Postgres/Redis are sketched in env variables instead of being shipped as compose profiles. None of those are unsafe defaults — they are scope decisions.

## Branch-by-Branch Assessment

### 1. `exp-gpt-5.5-high`

Production readiness is high because the production Compose file refuses to start without secrets, separates dev port exposure into the override, mounts configs read-only, and uses a Python-based liveness probe that does not rely on `curl` being present in the LiteLLM image. Security posture is the most consistent on the list: hardened Caddyfile, master-key required, telemetry off, key-info redaction, `.env` ignored. Documentation is clean — dev path, production path, authentication notes, basic-auth recipe, Ollama path, smoke-test, ops notes — without the bloat of irrelevant features. Modularity is moderate (Ollama via separate file, Postgres via env hooks); maintainability is strong because the surface area is small and intentional.

### 2. `exp-claude-opus-4-7-high`

This is the most feature-rich branch, and it wins on documentation, onboarding breadth, modularity, and developer experience. Concrete evidence:

- `exp-claude-opus-4-7-high:docker-compose.yml` ships profiled `db` (Postgres 16-alpine), `cache` (Redis 7-alpine with `--save 60 1`), and `ollama` services, plus a YAML anchor `&default-logging` that gives every service `json-file` rotation at `10m × 5`.
- `exp-claude-opus-4-7-high:Makefile` provides `init`, `up`, `up-prod`, `up-db`, `up-cache`, `up-ollama`, `logs-litellm`, `logs-caddy`, `pull`, `clean`, `key`, `salt`, plus auto-generated `make help`.
- `exp-claude-opus-4-7-high:scripts/init.sh` bootstraps `.env`, master key, and salt key idempotently. `scripts/gen-master-key.sh --write` updates `.env` portably.
- `exp-claude-opus-4-7-high:scripts/smoke-test.sh` is the most thorough on the list: liveness, readiness, models, and a real chat completion against a configurable model.
- `exp-claude-opus-4-7-high:Caddyfile` sets HSTS, security headers, JSON access logs, `trusted_proxies static private_ranges`, and matched `transport http` timeouts for LiteLLM streaming. The `health` matcher splits `/health*` and `/metrics` so they bypass any future hardening cleanly.
- `exp-claude-opus-4-7-high:docker-compose.override.yml` binds LiteLLM and dev Caddy to `127.0.0.1` only, so `make up` never accidentally exposes the dev stack on a LAN.
- `exp-claude-opus-4-7-high:.env.example` pins `LITELLM_IMAGE_TAG=main-stable` instead of `:latest`.
- The README contains an architecture diagram, file table, configuration recipes for each profile, observability notes, a security checklist, an operations cheatsheet, and a troubleshooting section.

It does not take the top spot because of permissive defaults, which I have to flag honestly even though this is "my" model's branch:

- `exp-claude-opus-4-7-high:docker-compose.yml` defines `LITELLM_MASTER_KEY: ${LITELLM_MASTER_KEY:-}`. A misconfigured `.env` lets the proxy boot with an empty master key — the opposite of `exp-gpt-5.5-high`'s `${LITELLM_MASTER_KEY:?...}` guard.
- `POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-}` allows an empty Postgres password when `--profile db` is enabled. Redis falls back to a literal `changeme` (`--requirepass ${REDIS_PASSWORD:-changeme}`).
- The Caddyfile mentions hardening but does not actually enable rate limiting, and `litellm-config.yaml` keeps `max_parallel_requests` / `tpm` / `rpm` commented out. The README's "Security checklist" treats these as user homework.

So the same engineering choices that make this the most flexible setup also make its defaults the most forgiving. With the `:?` guard, non-empty Postgres/Redis defaults, and at least one active rate limit, this branch would clearly contend for the top spot.

### 3. `exp-composer-2`

Production-ready in shape. `exp-composer-2:docker-compose.yml` keeps LiteLLM off the host network in the base file, uses `${LITELLM_MASTER_KEY:?Copy .env.example to .env and set LITELLM_MASTER_KEY}` for fail-fast, mounts config and helper scripts read-only, and waits for `service_healthy`. The healthcheck script `scripts/litellm-healthcheck.py` is genuinely clever — it probes `/health/liveliness`, `/health/readiness`, and `/` so the container stays healthy across LiteLLM versions that change paths. The Caddy reverse proxy explicitly handles SSE/streaming (`flush_interval -1`, large `read_timeout`/`write_timeout`) which several other branches forgot.

It loses points for omissions:

- `exp-composer-2:Caddyfile` has no security headers, no `admin off`, and does not consume `TLS_EMAIL` even though `.env.example` advertises it. The user has to wire ACME email manually.
- `exp-composer-2:docker-compose.override.yml` publishes LiteLLM on `4000:4000` (any interface) for dev rather than `127.0.0.1:4000:4000`.
- No bootstrap script, no smoke test, no telemetry-off / verbose-off / redact settings in `litellm-config.yaml`. The config is the smallest of the strong branches.
- `.env.example` and `env.example` are duplicated, which is more confusing than helpful.

Overall: a coherent, well-maintained minimal baseline; if it adopted GPT's Caddy hardening and `bootstrap-env.sh`, it would be very close to the top.

### 4. `exp-claude-4.6-sonnet-medium-thinking`

This branch has the most polished README and the most ambitious operations scripts: `scripts/prod-up.sh` validates `LITELLM_MASTER_KEY`, `LITELLM_SALT_KEY`, `CADDY_DOMAIN`, `CADDY_TLS_EMAIL`, and even refuses to start when values still contain placeholders like `change-me` or `example.com`. `scripts/generate-key.sh` calls LiteLLM's `/key/generate` to mint scoped virtual keys with `--models` and `--duration`. `litellm-config.yaml` has the largest curated model list, sets `telemetry: false`, retries, and timeouts, and gives a clean Ollama / Postgres / Redis expansion path.

It does not rank higher because of correctness and security risks in the production surface:

- `exp-claude-4.6-sonnet-medium-thinking:docker-compose.yml` publishes LiteLLM on `4000:4000` directly in the base file. The README itself says port 4000 should be firewalled in production, but the compose file binds it to all host interfaces.
- `exp-claude-4.6-sonnet-medium-thinking:Caddyfile` puts `header_up X-Real-IP {remote_host}` and similar `header_up` directives at site scope rather than inside the `reverse_proxy { ... }` block, and uses `tls {$CADDY_TLS_EMAIL}` (the email is meant to be a global `email` directive). Both are Caddyfile structure errors that should fail to parse on a real run.
- `exp-claude-4.6-sonnet-medium-thinking:scripts/health-check.sh` calls `/v1/models` with no `Authorization` header and asserts `200`. With `master_key: os.environ/LITELLM_MASTER_KEY` set in `litellm-config.yaml`, that endpoint should return `401`, so the health check is effectively self-defeating.
- The base healthcheck uses `curl -f http://localhost:4000/health/liveliness`; LiteLLM's official image has historically not always shipped `curl`, so this can break across image versions where the Python-based probes (`exp-gpt-5.5-high`, `exp-claude-opus-4-7-high`, `exp-composer-2`) do not.
- The Compose files keep the `version: "3.9"` field (deprecated for Compose v2). It is harmless but signals stale conventions.

Strong intent and great docs; needs the production correctness fixed.

### 5. `exp-auto`

Reasonable structure and a tidy split between `.env.example` (production-style) and `.env.dev.example` (local) — the only branch that makes that separation explicit. Helper scripts (`up.sh`, `down.sh`, `logs.sh`, `ps.sh`, `health.sh`) are small but consistent.

The security model is muddled and that is what holds it back:

- `exp-auto:docker-compose.yml` exposes LiteLLM directly on host port `4000` in the base file (`ports: - "4000:4000"`), making Caddy optional rather than mandatory.
- `exp-auto:Caddyfile` requires `basicauth` with `{$CADDY_BASIC_AUTH_USER}` / `{$CADDY_BASIC_AUTH_HASH}`, but `.env.example` ships those as empty placeholders. A user following the quickstart will either get a Caddy parse error or unintentionally allow a placeholder credential.
- The Caddy `/health`, `/healthz`, `/readyz` matcher returns a synthetic `respond "ok" 200`, so the public health endpoint reports green even when LiteLLM is down — the opposite of what a health probe should do.
- `LITELLM_API_KEYS` is set as an env variable on the LiteLLM container, but `litellm-config.yaml` only wires `general_settings.master_key`. There is no clear plumbing of `LITELLM_API_KEYS` into a non-admin authorization concept, so the env variable is decorative.

Useful as a starting point; needs security cleanup before it should be used to terminate real traffic.

### 6. `exp-gemini-3.1-pro`

This is the weakest of the six and has multiple production-blocking defects:

- `exp-gemini-3.1-pro:docker-compose.yml` falls back to `LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY:-default-master-key}`, so a missing `.env` produces a publicly reachable proxy with a hardcoded admin key.
- The same file passes `--detailed_debug` to LiteLLM and `litellm-config.yaml` sets `set_verbose: true`. Both leak detail into logs.
- LiteLLM is published on host port `4000:4000` in the base file (no `expose`-only path).
- `exp-gemini-3.1-pro:Caddyfile` hardcodes `example.com` instead of using a `$DOMAIN` env var, even though `.env.example` defines `DOMAIN`. The README acknowledges that the user must hand-edit the file before going to production.
- The healthcheck uses `curl -f http://localhost:4000/health` and again depends on `curl` existing in the LiteLLM image; stronger branches use Python `urllib` or LiteLLM's own `liveliness` / `readiness` paths.
- The Compose files use `version: "3.8"` (deprecated in Compose v2).
- There is no `.gitignore`, so a user copying `.env.example` to `.env` would commit secrets by default. Every other branch ignores `.env`.
- Documentation is short and gives no observability, no expansion strategy beyond a single pasted Ollama snippet, and no security checklist.

Acceptable for a five-minute prototype, not as an infrastructure baseline.

## Criteria Summary

| Branch | Production readiness | Security | Documentation / onboarding | Developer experience | Modularity / extensibility | Maintainability |
| --- | --- | --- | --- | --- | --- | --- |
| `exp-gpt-5.5-high` | Strong (fail-fast secrets, no host port for LiteLLM) | Strongest (HSTS, admin off, telemetry off, redaction) | Strong | Strong (Make + bootstrap + smoke) | Good (Ollama overlay, basic-auth example) | Strong (small, focused) |
| `exp-claude-opus-4-7-high` | Strong shape, **permissive defaults** | Strong scaffolding, weak defaults (empty master key, weak Postgres/Redis) | Strongest (architecture, checklist, troubleshooting) | Strongest (Makefile, init, smoke incl. chat round-trip) | Strongest (db/cache/ollama profiles, log rotation) | Good but largest surface |
| `exp-composer-2` | Good (`:?` guard, smart healthcheck) | Mixed (no Caddy hardening, TLS_EMAIL unwired) | Good | Good | Moderate (Ollama overlay only) | Strong |
| `exp-claude-4.6-sonnet-medium-thinking` | Mixed (LiteLLM on host, Caddy syntax issues) | Mixed (good prod-up validation; broken health-check; debug in dev) | Strongest among mid-tier | Good (`generate-key.sh`, validations) | Good (Ollama overlay; Postgres/Redis as snippets) | Mixed (correctness issues) |
| `exp-auto` | Mixed (LiteLLM on host, basic auth half-wired) | Weak to mixed (synthetic health, placeholder auth) | Adequate | Good (clean `.env`/`.env.dev` split) | Moderate (Ollama profile only) | Moderate |
| `exp-gemini-3.1-pro` | Weak (default master key, host port, deprecated version field, no .gitignore) | Weak | Basic | Basic | Weak | Weak |

## Final Verdict

Adopt `exp-gpt-5.5-high` as the baseline. It is the only branch where the production Compose file actually refuses to start with missing secrets, the only public entrypoint is Caddy, the Caddy configuration is hardened, telemetry is off, and the documented quickstart actually generates good secrets instead of asking the user to invent them.

If continuing the work, the most valuable next step is to port the best parts of `exp-claude-opus-4-7-high` on top of `exp-gpt-5.5-high`:

1. The profiled `db` / `cache` / `ollama` services and the `&default-logging` log-rotation anchor.
2. The deeper smoke test (liveness + readiness + models + chat completion).
3. The `Makefile` targets (`up-db`, `up-cache`, `up-ollama`, `logs-litellm`, `logs-caddy`, `clean`).
4. The pinned `LITELLM_IMAGE_TAG=main-stable` instead of `:latest`.

But keep `exp-gpt-5.5-high`'s strict Compose `:?` guards on `LITELLM_MASTER_KEY` / `GATEWAY_DOMAIN`, its hardened Caddyfile (no admin endpoint, full security headers), its `redact_user_api_key_info: true` LiteLLM setting, and its `127.0.0.1`-bound dev override discipline. That hybrid is the cleanest path to a production-ready LiteLLM gateway.
