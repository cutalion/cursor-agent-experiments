# LiteLLM Infrastructure Experiment Verdict: gpt-5.5-high

## Final Ranking

1. `exp-gpt-5.5-high`
2. `exp-claude-opus-4-7-high`
3. `exp-composer-2`
4. `exp-claude-4.6-sonnet-medium-thinking`
5. `exp-auto`
6. `exp-gemini-3.1-pro`

## Best Setup: `exp-gpt-5.5-high`

`exp-gpt-5.5-high` is the best overall setup. It is not the most feature-rich branch, but it has the strongest balance of production safety, clarity, onboarding, and maintainability. The production Compose file keeps LiteLLM internal-only with `expose: "4000"` and puts Caddy on public `80/443`, requires `LITELLM_MASTER_KEY` and `GATEWAY_DOMAIN` with Compose `:?` guards, mounts `litellm-config.yaml` read-only, waits for LiteLLM health before starting Caddy, and includes Caddy TLS/security headers plus upstream health checks.

Concrete evidence:

- `exp-gpt-5.5-high:docker-compose.yml` requires `LITELLM_MASTER_KEY`, requires `GATEWAY_DOMAIN`, uses `restart: unless-stopped`, adds a LiteLLM healthcheck, and exposes LiteLLM only on the Docker network in the base production file.
- `exp-gpt-5.5-high:docker-compose.override.yml` cleanly separates development exposure: direct LiteLLM on `${DEV_LITELLM_PORT:-4000}` and Caddy on `${DEV_CADDY_PORT:-8080}`.
- `exp-gpt-5.5-high:Caddyfile` disables the Caddy admin endpoint, enables compression, adds HSTS and other security headers, removes `Server`, and uses `reverse_proxy` health probing.
- `exp-gpt-5.5-high:litellm-config.yaml` keeps credentials in environment variables, disables telemetry, redacts user API key information, enables retries/cooldowns, and provides model aliases.
- `exp-gpt-5.5-high:scripts/bootstrap-env.sh` generates both a master key and salt key instead of asking users to invent secrets manually.
- `exp-gpt-5.5-high:scripts/smoke-test.sh` checks liveness and, when a key is available, authenticated `/v1/models`.
- `exp-gpt-5.5-high:README.md` gives a clear dev path, production path, authentication notes, Ollama usage, smoke test, and operational notes.

The main gaps are that it uses `ghcr.io/berriai/litellm:latest` instead of an immutable version, relies on the newer Compose `!override` tag, and only sketches future Postgres support rather than shipping a profiled Postgres service. Those are real issues, but they are easier to fix than unsafe defaults or invalid production configs.

## Branch-by-Branch Assessment

### 1. `exp-gpt-5.5-high`

This branch is production-ready for a small gateway and has the safest default shape. Caddy is the only public entrypoint in the base stack, required secrets fail fast, configs are mounted read-only, and dev-only direct exposure lives in the override file. Security is also comparatively strong: Caddy hardening headers are present, `.env` is ignored, secrets are referenced through environment variables, telemetry is disabled, and a basic-auth Caddy example is provided.

Documentation and developer experience are concise but complete: `bootstrap-env.sh`, `smoke-test.sh`, `Makefile`, `docker-compose.ollama.yml`, and clear README instructions cover the common path without overbuilding the stack. Modularity is good through separate compose files and config-driven providers, though less complete than Opus because there are no included Postgres or Redis services.

### 2. `exp-claude-opus-4-7-high`

This is the richest setup and wins on documentation, onboarding breadth, and extensibility. It includes a large `Makefile`, `make init`, `make up-db`, `make up-cache`, `make up-ollama`, service log rotation, optional Postgres/Redis/Ollama profiles, Azure/Mistral examples, a thorough README, and a smoke test that checks liveness, readiness, models, and chat completions.

It loses the top spot on security and production strictness. `exp-claude-opus-4-7-high:docker-compose.yml` sets `LITELLM_MASTER_KEY: ${LITELLM_MASTER_KEY:-}` instead of failing when missing, so a misconfigured production launch can proceed with an empty master key. Postgres and Redis also allow weak or empty defaults (`POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-}` and Redis defaulting to `changeme`). The Caddyfile comments mention rate limiting, but no active rate-limit directive is implemented. The branch is very capable, but its permissive defaults make it slightly less safe as the best recommendation.

### 3. `exp-composer-2`

This is a solid minimal implementation. The base Compose file keeps LiteLLM off host ports in production, requires `LITELLM_MASTER_KEY`, waits for the LiteLLM healthcheck, mounts config read-only, and uses Caddy as the public edge. It has a pragmatic healthcheck helper that probes multiple LiteLLM health URLs, simple helper scripts, JSON Caddy logs, and an optional Ollama compose fragment.

The downsides are mostly omissions. `exp-composer-2:Caddyfile` lacks the security headers and HSTS found in the stronger branches. `TLS_EMAIL` exists in `.env.example` but is not wired into the Caddyfile. There is no generated-secret bootstrap, no Postgres/Redis persistence option, and no included smoke test despite the branch stat showing operational wrappers. It is maintainable and coherent, but not as production-complete as GPT or Opus.

### 4. `exp-claude-4.6-sonnet-medium-thinking`

This branch has strong documentation and some useful operations ideas: `scripts/prod-up.sh` validates required production variables, `scripts/generate-key.sh` creates LiteLLM virtual keys, the README explains API usage and expansion, and the LiteLLM config covers many providers plus retries and telemetry disablement.

It ranks lower because the production surface has correctness and security risks. `exp-claude-4.6-sonnet-medium-thinking:docker-compose.yml` publishes LiteLLM directly on host port `4000` in the base file even though the README says port 4000 should be firewalled in production. `exp-claude-4.6-sonnet-medium-thinking:Caddyfile` appears to put `header_up` directives at site scope rather than inside `reverse_proxy`, which is not valid Caddyfile structure. `scripts/health-check.sh` expects `/v1/models` to return 200 without an Authorization header, which is unlikely for a properly protected LiteLLM proxy. These issues undercut an otherwise promising setup.

### 5. `exp-auto`

`exp-auto` has reasonable structure and useful helper scripts, but the security model is muddled. The base Compose file exposes LiteLLM on host port `4000`, Caddy basic auth is enabled in the production Caddyfile using placeholder variables, and the Caddy health route returns a synthetic `ok` instead of checking the upstream. It also introduces `LITELLM_API_KEYS` as an environment-level access control concept, but the LiteLLM config only clearly wires `general_settings.master_key`, so the intended non-admin key behavior is not well substantiated by the config.

The documentation is adequate for local use, and the split between `.env.example` and `.env.dev.example` is convenient. Still, compared with the top branches, it needs security cleanup and stronger validation before production use.

### 6. `exp-gemini-3.1-pro`

This is the weakest setup. The production Caddyfile hardcodes `example.com` instead of using the `DOMAIN` environment variable, the production Compose file publishes LiteLLM directly on `4000:4000`, and `LITELLM_MASTER_KEY` falls back to `default-master-key`. It also starts LiteLLM with `--detailed_debug` in the base file and sets `set_verbose: true` in `litellm-config.yaml`, which is inappropriate for production. The healthcheck depends on `curl` being present in the LiteLLM image and targets `/health`, while stronger branches use Python or known liveness/readiness endpoints.

The README is short and approachable, but it asks the user to manually edit the Caddyfile for production and does not provide enough operational or security depth. This branch is useful as a prototype, not as a recommended infrastructure baseline.

## Criteria Summary

| Branch | Production readiness | Security | Documentation/onboarding | Developer experience | Modularity/extensibility | Maintainability |
| --- | --- | --- | --- | --- | --- | --- |
| `exp-gpt-5.5-high` | Strong | Strongest | Strong | Strong | Good | Strong |
| `exp-claude-opus-4-7-high` | Strong but permissive | Good, with unsafe defaults | Strongest | Strongest | Strongest | Good, but more complex |
| `exp-composer-2` | Good | Good | Good | Good | Moderate | Strong |
| `exp-claude-4.6-sonnet-medium-thinking` | Mixed | Mixed | Strong | Good | Good | Mixed due config issues |
| `exp-auto` | Mixed | Weak to mixed | Adequate | Good | Moderate | Moderate |
| `exp-gemini-3.1-pro` | Weak | Weak | Basic | Basic | Weak | Weak |

## Final Verdict

Choose `exp-gpt-5.5-high` as the baseline. It has the fewest dangerous surprises while still giving a complete Docker Compose, Caddy, LiteLLM, dev override, local model, bootstrap, and smoke-test workflow. If continuing the work, the best follow-up would be to borrow Opus's profiled Postgres/Redis/log-rotation ideas, but keep GPT's stricter required environment variables and simpler production boundary.
