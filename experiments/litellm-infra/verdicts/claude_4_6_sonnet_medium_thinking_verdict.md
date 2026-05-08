# LiteLLM Infrastructure Experiment — Verdict

**Model:** claude-4.6-sonnet-medium-thinking  
**Evaluated branches:** exp-gpt-5.5-high, exp-claude-opus-4-7-high, exp-composer-2, exp-gemini-3.1-pro, exp-auto, exp-claude-4.6-sonnet-medium-thinking

---

## Winner: `exp-claude-opus-4-7-high`

This branch achieves the best balance across every evaluation axis. It is the only implementation where all six concerns — production readiness, security, documentation, developer experience, modularity, and maintainability — are addressed with explicit, concrete decisions rather than left as implied or omitted.

---

## Rankings

| Rank | Branch | Score |
|------|--------|-------|
| 1 | exp-claude-opus-4-7-high | Best overall |
| 2 | exp-gpt-5.5-high | Strong runner-up |
| 3 | exp-auto | Solid middle tier |
| 4 | exp-claude-4.6-sonnet-medium-thinking | Good but has a few regressions |
| 5 | exp-composer-2 | Minimal and functional |
| 6 | exp-gemini-3.1-pro | Weakest across the board |

---

## Detailed Analysis

### 1 — `exp-claude-opus-4-7-high` ✅ Winner

**Production readiness:**  
- Uses `ghcr.io/berriai/litellm:main-stable` — the only branch besides mine to avoid `:latest` or `:main-latest`. Pinned, stable, predictable.  
- LiteLLM is never published to the host in production (`expose` only); Caddy is the sole public surface. All other branches expose port 4000 directly.  
- `x-logging` YAML anchor applies consistent log rotation (`json-file`, `max-size: 10m`, `max-file: 5`) to every service — avoids disk-fill in long-lived containers.  
- HTTP/3 support via `443:443/udp`.  
- `depends_on: condition: service_healthy` on Caddy waiting for LiteLLM to pass healthcheck before accepting traffic.

**Security:**  
- Caddyfile sets `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, and strips the `Server` header.  
- Optional basic auth is correctly gated behind commented-out blocks with instructions — present but not forced.  
- `POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set}` in `compose/postgres.yml` blocks startup with a clear message if the secret is missing rather than silently using a default.  
- `litellm-config.yaml` explicitly sets `allow_unauthenticated_model_list: false`.

**Documentation and onboarding:**  
- README includes an ASCII architecture diagram, step-by-step production deploy flow, virtual key management example (with full curl snippet), GPU GPU Ollama instructions, and an operations cheatsheet table.  
- `litellm-config.yaml` is the most thoroughly commented config file across all branches — every block has a rationale comment, not just a label.  
- `make help` prints a colour-formatted target list because Makefile targets carry `## description` annotations.

**Developer experience:**  
- `make dev`, `make prod`, `make prod-pg`, `make prod-pg-ollama` cover the full matrix of runtime modes with single commands.  
- `scripts/gen-keys.sh` generates both LITELLM_MASTER_KEY and LITELLM_SALT_KEY in one invocation and can append directly to `.env`.  
- `scripts/caddy-hash.sh` generates bcrypt hashes without requiring the developer to remember the docker run incantation.  
- `scripts/test-request.sh` accepts a model argument and an optional `GATEWAY_URL` env var, so the same script works in dev, against prod, and in CI.

**Modularity and extensibility:**  
- Postgres and Ollama are optional overlays (`compose/postgres.yml`, `compose/ollama.yml`) rather than bundled into the base stack. The base compose is the minimal required surface.  
- Each overlay is self-contained and annotated with the exact `docker compose -f` incantation to use it.  
- `litellm-config.yaml` includes commented-out entries for TGI, Ollama, Redis cache, Langfuse callbacks, context-window fallbacks, and budget settings — all commented out but ready.

**Maintainability:**  
- Anchored logging block means changing log config is a one-line edit.  
- `docker-compose.override.yml` uses the `!override` YAML tag to fully replace the Caddy ports list, avoiding merge-confusion where dev and prod port lists silently combine.  
- `README` documents the exact Docker Compose version requirement (≥ 2.24) caused by this tag — a rare but important caveat made explicit.

**Weaknesses:**  
- The `!override` tag requires Docker Compose ≥ 2.24, which may break on older hosts. The README calls this out but it remains a footgun.  
- `Makefile` has no explicit `.env` guard; `make dev` will fail noisily if `.env` is missing rather than guiding the user.

---

### 2 — `exp-gpt-5.5-high`

**Strengths:**  
- `scripts/bootstrap-env.sh` is the most operator-friendly first-run experience of any branch. It generates LITELLM_MASTER_KEY, UI_PASSWORD, POSTGRES_PASSWORD, and — if Docker is available — runs `caddy hash-password` and patches all values directly into `.env` in one command. No developer needs to remember how to generate a bcrypt hash.  
- `docs/` directory with `operations.md` and `providers.md` is the most thorough separate documentation in any branch. `operations.md` covers health checks, backup commands, upgrade procedure, and rate limiting guidance.  
- Postgres is bundled in the base compose — more opinionated but means the full key management and UI experience works without an extra flag.  
- LiteLLM healthcheck avoids `curl` dependency by using `python -c "import urllib.request; ..."`, which is always available in the container.  
- Makefile covers the full lifecycle including `make ollama-up`.

**Weaknesses:**  
- Caddyfile has no security headers — the most significant omission for a production gateway.  
- `image: ghcr.io/berriai/litellm:latest` is the untagged latest, which will silently pick up breaking upstream changes.  
- Postgres always-on inflates the minimum resource footprint and startup time even when persistence is not needed.  
- `.gitignore` present but the dev override hardcodes `litellm-dev-password` as a Postgres default — less careful than branches using `?:` enforcement.

---

### 3 — `exp-auto`

**Strengths:**  
- Two separate env templates (`.env.example` for production, `.env.dev.example` for development) make the prod/dev configuration boundary explicit without relying on default substitutions.  
- Caddyfile handles CORS OPTIONS preflight — the only branch that does.  
- Caddyfile includes security headers (HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy).  
- Caddy image is pinned to `caddy:2.8` rather than `2-alpine`, which is reproducible.  
- `LITELLM_SALT_KEY` included in env templates for encrypted virtual key storage.  
- Ollama is behind a compose profile (`local-llm`), keeping the base stack minimal.  
- Caddy's reverse_proxy block includes `health_uri`, `health_interval`, `fail_duration`, and `lb_try_duration` for active upstream health management.

**Weaknesses:**  
- `LITELLM_MASTER_KEY` and `LITELLM_SALT_KEY` in the base compose have no fallback — the stack will crash at startup if `.env` is missing or incomplete, with a Docker error rather than a helpful message.  
- Caddy healthcheck uses `["CMD", "caddy", "version"]`, which only confirms the binary exists, not that Caddy is actually serving requests.  
- Basic auth is always-on in the Caddyfile with no disable path — cannot run without setting hash values.  
- No Makefile.

---

### 4 — `exp-claude-4.6-sonnet-medium-thinking` (this model's own branch)

**Strengths:**  
- README is comprehensive: architecture diagram, dev/prod quickstart, virtual key docs, routing strategy table, observability section with Prometheus scrape config example.  
- Caddyfile has the most complete security header set (adds `X-XSS-Protection` and removes `Server` header; uses JSON access logs).  
- `scripts/start.sh` handles `dev`, `prod`, and `ollama` combinations with mode detection and friendly status output.  
- `scripts/health.sh` is the most thorough health checker: shows `docker compose ps`, checks liveliness, readiness, models endpoint, gateway, and runs a chat completion smoke test.  
- `scripts/keygen.sh` automates virtual key provisioning via the LiteLLM API.  
- Separate `docker-compose.ollama.yml` + `litellm-config.ollama.yaml` for clean Ollama opt-in.  
- `LANGFUSE_*` env vars in `.env.example` hint at observability integration.

**Weaknesses:**  
- `version: "3.9"` in both `docker-compose.yml` and `docker-compose.override.yml`. The `version` field has been deprecated in Compose v2 and emits warnings; the winning branch omits it entirely.  
- LiteLLM is published as `4000:4000` (not `127.0.0.1:4000:4000`). In production, where Caddy should be the only public surface, this exposes the unauthenticated LiteLLM port to all interfaces.  
- The `model_list` includes a wildcard passthrough entry (`model_name: "*"`) that forwards any unrecognized model directly to OpenAI. The README flags this as a security concern, but shipping it enabled by default is the wrong default.  
- `depends_on: []` in the litellm service is a no-op and adds noise.  
- Dev override mounts `litellm-config.yaml` as read-write (without `:ro`), which is noted as intentional but reduces the value of the read-only production mount as a guard.

---

### 5 — `exp-composer-2`

**Strengths:**  
- Uses `LITELLM_MASTER_KEY: ${LITELLM_MASTER_KEY:?Set LITELLM_MASTER_KEY in .env (see .env.example)}` — the only branch besides claude-opus that uses the `?:` form to provide a helpful error message on startup if the variable is missing.  
- HTTP/3 via `443:443/udp`.  
- Caddy uses `health_uri`, `health_interval`, `health_timeout`, and `fail_duration` for active upstream health tracking.  
- Long read/write timeouts (600s) for streaming completions.  
- `env_file: required: false` so the stack can start without an `.env` file in dev, picking up defaults.

**Weaknesses:**  
- No Makefile, no docs directory, no key generation script. Onboarding is purely README-driven.  
- No security headers in Caddyfile.  
- `litellm-config.yaml` comments out the `general_settings.master_key` field, relying on the env var being read implicitly — creates a silent inconsistency where the config file does not document the full effective configuration.  
- Only two helper scripts (`caddy-hash-password.sh`, `smoke-test.sh`) covering the narrowest operational surface of all branches.

---

### 6 — `exp-gemini-3.1-pro` (weakest)

**Weaknesses (concrete evidence):**  
- `version: '3.8'` in both compose files — a deprecated field that generates warnings in every Compose v2 invocation.  
- No `.gitignore` — the only branch without one.  
- `image: ghcr.io/berriai/litellm:main-latest` — least stable tag choice. `main-latest` tracks every merge commit.  
- `restart: always` instead of `restart: unless-stopped` — will restart even after a deliberate `docker compose stop`, fighting the operator.  
- `healthcheck` uses `["CMD", "curl", "-f", "http://localhost:4000/health"]` — the `/health` endpoint does upstream provider checks and can fail spuriously; `/health/liveliness` is the correct target for container health.  
- Caddy `depends_on: - litellm` without a `condition: service_healthy`, so Caddy can start before LiteLLM is ready.  
- Caddyfile has no security headers, no compression, no access logging.  
- `litellm-config.yaml` includes only two provider entries and minimal settings — least useful as a starting point.  
- `.env.example` has four lines; the next-smallest has over 20.  
- README provides one-liner instructions only, no production guidance, no security section.

---

## Key Differentiators Summary

| Concern | Winner (claude-opus-4-7-high) advantage |
|---|---|
| Production readiness | LiteLLM not published to host; `main-stable` image; log rotation |
| Security | Full security header suite; `POSTGRES_PASSWORD:?` enforcement; `allow_unauthenticated_model_list: false` |
| Documentation | Architecture diagram; operations cheatsheet; richly commented config |
| Developer experience | Self-documenting `make help`; `gen-keys.sh`; `caddy-hash.sh`; flexible test script |
| Modularity | Postgres and Ollama as opt-in overlays; base stack minimal by default |
| Maintainability | Anchored logging; `!override` tag for port replacement; all decisions documented inline |
