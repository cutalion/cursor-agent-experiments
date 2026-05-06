# LiteLLM Infrastructure Experiment Verdict: composer-2

## Final ranking

1. `exp-gpt-5.5-high`
2. `exp-claude-opus-4-7-high`
3. `exp-composer-2`
4. `exp-claude-4.6-sonnet-medium-thinking`
5. `exp-auto`
6. `exp-gemini-3.1-pro`

## Best setup: `exp-gpt-5.5-high`

`exp-gpt-5.5-high` is the best default for teams that need a **small, defensible production boundary** without inheriting unsafe fallbacks. The production `docker-compose.yml` fails fast on missing secrets, keeps LiteLLM off the public host network (only `expose: "4000"`; Caddy owns `80`/`443`), and pairs that with a Caddyfile that turns off the admin API and sets HSTS plus standard security headers. LiteLLM is configured with telemetry off, verbose off, key-info redaction, retries, and cooldowns. Onboarding is practical: `scripts/bootstrap-env.sh` generates master and salt material, `scripts/smoke-test.sh` checks liveness and (when configured) authenticated `/v1/models`, and the README documents dev vs prod compose usage and the `!override` dev override caveat.

Concrete evidence (inspect with `git show exp-gpt-5.5-high:<path>`):

- **Production readiness:** `${LITELLM_MASTER_KEY:?...}` and `${GATEWAY_DOMAIN:?...}`; Python `urllib`-based LiteLLM healthcheck (no reliance on `curl` in the image); `depends_on` with `condition: service_healthy` for Caddy after LiteLLM.
- **Security:** `Caddyfile` contains `admin off`, HSTS, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy`, `-Server`; `reverse_proxy` upstream health probing; `litellm-config.yaml` sets `telemetry: false`, `redact_user_api_key_info: true`, `drop_params: true`; `examples/Caddyfile.basic-auth` for optional edge auth.
- **Documentation / DX:** README covers bootstrap, smoke test, production-only compose, authentication notes, Ollama path, Compose `!override` requirement; `Makefile` exists for helpers (per tree).
- **Modularity:** Optional `docker-compose.ollama.yml`; model list covers multiple providers plus Ollama hook in config.
- **Maintainability:** Small file set (see `git ls-tree -r --name-only exp-gpt-5.5-high`); no optional PostgreSQL/Redis services to keep patched—scope is intentionally tight.

Honest gaps: the stack pins `ghcr.io/berriai/litellm:latest` (mutable tag), the dev override relies on Compose `!override` (needs a current Compose v2), and Postgres/Redis are not shipped as compose profiles—you add them later if needed.

---

## Runner-up assessments (with concrete evidence)

### 2. `exp-claude-opus-4-7-high`

Wins hardest on **features, documentation breadth, onboarding surface, and extensibility.**

- **Modularity:** `docker-compose.yml` adds YAML-anchor `json-file` log rotation (`10m`, `max-file: "5"`); `--profile db` Postgres 16-alpine; `--profile cache` Redis 7-alpine with `--save 60 1`; `--profile ollama`; image tag `${LITELLM_IMAGE_TAG:-main-stable}` (better than `:latest`).
- **Developer experience:** `Makefile` targets (`init`, `up`, profiles, logs, `pull`, etc., per repo tree); `scripts/init.sh` and `scripts/gen-master-key.sh`; `scripts/smoke-test.sh` is the most ambitious (liveness/readiness/models/chat-oriented checks, per workflow intent).
- **Edge proxy:** `Caddyfile` sets `trusted_proxies`, JSON access logs, streaming-aligned `transport http` timeouts (`read_timeout`/`write_timeout` 600s), and a `@health` path matcher for `/health*` and `/metrics`. `docker-compose.override.yml` binds dev LiteLLM and Caddy to `127.0.0.1` only—strong local-safety story.

It is not ranked first because **production safety defaults are too permissive** relative to `exp-gpt-5.5-high`:

- `LITELLM_MASTER_KEY: ${LITELLM_MASTER_KEY:-}` allows an empty master key if `.env` is wrong.
- Postgres `POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-}` allows empty passwords when `--profile db` is used; Redis `--requirepass` defaults `${REDIS_PASSWORD:-changeme}` (weak predictable default unless overridden).
- The Caddy comments mention a lightweight rate limit, but there is **no active `rate_limit` directive** in the checked-in `Caddyfile`.

---

### 3. `exp-composer-2`

Ranks third: **clean minimal shape** with thoughtful operational details but **thin hardening vs the top two.**

- **Strengths:** Base `docker-compose.yml` avoids publishing LiteLLM on the host in the production-shaped file (no host `ports:` mapping on `litellm`); `${LITELLM_MASTER_KEY:?...}` fails fast; `depends_on ... condition: service_healthy`; mounts `litellm-config.yaml` read-only; `scripts/litellm-healthcheck.py` probes multiple endpoints—robust across LiteLLM path changes.
- **Edge / streaming:** `Caddyfile` sets long HTTP transport timeouts **and** `flush_interval -1` for SSE—some branches omitted streaming ergonomics entirely.
- **Gaps:** `Caddyfile` has **no** `admin off`, **no** HSTS/security headers, and **`TLS_EMAIL` is not wired** into TLS/`email` despite appearing in compose environment. `litellm-config.yaml` omits telemetry/verbose/redaction toggles present in stronger branches. `.env.example` **and** `env.example` duplicate—confusing for onboarding. `docker-compose.override.yml` publishes `4000:4000` on all interfaces (not restricted to `127.0.0.1`), weaker than Opus/GPT dev binding discipline.

---

### 4. `exp-claude-4.6-sonnet-medium-thinking`

Shows strong **intent** (`scripts/prod-up.sh`, `scripts/generate-key.sh`, long README, rich `litellm-config.yaml`), but the checked-in artifacts have **multiple sharp edges for production and verification.**

- **Production surface:** `docker-compose.yml` publishes **`4000:4000`** for LiteLLM on the base file—in tension with “Caddy-only public edge” posture.
- **Caddy correctness risk:** `Caddyfile` uses `tls {$CADDY_TLS_EMAIL}` at site scope—ACME registration email is normally a global `{ email ... }` (or Automatic HTTPS defaults), so this layout is dubious and may fail validation or behave unexpectedly versus the patterns used in Opus/GPT branches.
- **Directive placement:** `header_up X-Real-IP ...` appears at site level; in typical Caddy v2 style these belong **inside** `reverse_proxy { ... }` (as in `exp-claude-opus-4-7-high`), so this file is higher risk.
- **Health checks:** container healthcheck uses `curl` against `/health/liveliness` (may break if `curl` is absent in some image builds). `scripts/health-check.sh` expects `/v1/models` **HTTP 200 without `Authorization`**, which is unlikely when `master_key` is enforced—so the script can report false failures for a correctly secured proxy.

---

### 5. `exp-auto`

Reasonable **structure** (split `.env` examples, helper scripts) but mixed **security model and edge behavior.**

- **Host exposure:** `litellm` both `expose`s and maps **`4000:4000`**, so LiteLLM is directly reachable on the host, not only via Caddy.
- **Edge health:** `Caddyfile` `handle @health` responds **static `ok` 200** for `/health` routes instead of proxying LiteLLM—**masks upstream failures** at the perimeter.
- **Perimeter auth:** `basicauth /*` is enabled with env-provided placeholders—easy to ship with uninitialized hashes if templates are copied carelessly (`LITELLM_API_KEYS` is present in Compose but wiring in `litellm-config.yaml` is primarily `master_key`, so key semantics are unclear without extra LiteLLM features).

---

### 6. `exp-gemini-3.1-pro`

Clear last place—**unsafe defaults and dev-only habits in the baseline path.**

- `docker-compose.yml` sets `LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY:-default-master-key}`, publishes **`4000:4000`**, and starts LiteLLM with **`--detailed_debug`** in the production-shaped file.
- `Caddyfile` **hardcodes** `example.com` instead of parameterized domain-driven config (`exp-gpt-5.5-high`/`exp-claude-opus-4-7-high` solve this cleanly).
- `litellm-config.yaml` sets **`set_verbose: true`** globally.

---

## Criteria summary

| Branch | Production readiness | Security | Documentation & onboarding | Developer experience | Modularity & extensibility | Maintainability |
| ------ | -------------------- | -------- | -------------------------- | ---------------------- | -------------------------- | ----------------- |
| `exp-gpt-5.5-high` | **Strongest** boundary + fail-fast | **Strongest** baked-in defaults | Strong, concise | Strong | Good (optional Ollama file, env-driven providers) | **High** (small footprint) |
| `exp-claude-opus-4-7-high` | Strong (profiles, rotations) but permissive secrets | Good ideas, unsafe fallbacks | **Strongest breadth** | **Strongest tooling** | **Strongest** (db/cache/ollama profiles) | Moderate complexity cost |
| `exp-composer-2` | Good network split; lacks edge headers | **Gaps** (no HSTS bundle; TLS email unused) | Adequate | Good scripts | Moderate (Ollama fragment) | **High** minimalism |
| `exp-claude-4.6-sonnet-medium-thinking` | Mixed (port publish; TLS layout risk) | Mixed | Strong narrative | Good scripts | Good config surface | Hurt by correctness issues |
| `exp-auto` | Mixed (double exposure; synthetic health) | Mixed / confusing | Adequate | Adequate | Moderate (ollama profile) | Moderate |
| `exp-gemini-3.1-pro` | Weak | Weak | Basic | Basic | Weak | Weak |

---

## Final verdict

**Adopt `exp-gpt-5.5-high` as the recommended baseline**: it offers the best balance of **safe defaults**, **clear network boundaries**, **defensive LiteLLM settings**, and **repeatable onboarding** (bootstrap + smoke test) with evidence-backed configuration choices.

**Next step if you outgrow it:** lift **profiles, log rotation, and Makefile ergonomics** from `exp-claude-opus-4-7-high`, but **retain** `exp-gpt-5.5-high`-style **required** `LITELLM_MASTER_KEY` / database password rules and **avoid** empty-string fallbacks for secrets.
