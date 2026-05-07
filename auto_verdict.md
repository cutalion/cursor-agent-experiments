# Auto Verdict: LiteLLM Infra Branch Evaluation

## Winner
**`exp-claude-opus-4-7-high`**

## Why this branch wins
`exp-claude-opus-4-7-high` has the best overall balance across production readiness, security, onboarding, developer experience, extensibility, and maintainability.

Concrete evidence:
- **Production readiness:** clear base-plus-overlay architecture with `docker-compose.yml`, `compose/postgres.yml`, and `compose/ollama.yml`; operational scripts for prod/dev flows in `scripts/prod-up.sh` and `scripts/dev-up.sh`.
- **Security:** environment preflight checks in `scripts/_check-env.sh`; defensive reverse-proxy defaults and headers in `Caddyfile`.
- **Documentation/onboarding:** comprehensive setup and architecture guidance in `README.md` and `.env.example`.
- **Developer experience:** useful commands and repeatable workflows via `Makefile`, plus helper scripts like `scripts/logs.sh` and `scripts/test-request.sh`.
- **Modularity/extensibility:** compose overlay pattern and configurable model catalog in `litellm-config.yaml`.
- **Maintainability:** structured script boundaries and consistent operational conventions reduce long-term drift.

## Ranking (best to worst)
1. `exp-claude-opus-4-7-high`
2. `exp-gpt-5.5-high`
3. `exp-claude-4.6-sonnet-medium-thinking`
4. `exp-auto`
5. `exp-composer-2`
6. `exp-gemini-3.1-pro`

## Reasoning by branch

### 1) `exp-claude-opus-4-7-high` (Best)
- Most complete and production-oriented structure.
- Strong docs and operational ergonomics.
- Best guardrails before runtime.
- **Caveat:** ensure gateway auth is enabled by default in production if currently commented in `Caddyfile`.

### 2) `exp-gpt-5.5-high`
- Very strong docs (`docs/operations.md`, `docs/providers.md`) and validation tooling (`scripts/check-config.sh`, `scripts/smoke-test.sh`).
- Good auth-aware proxy setup in `caddy/Caddyfile`.
- **Why not #1:** risky production fallback secrets in `docker-compose.yml` (e.g., defaulting sensitive values) weaken hardening.

### 3) `exp-claude-4.6-sonnet-medium-thinking`
- Broad script support and readable onboarding (`README.md`, `scripts/*.sh`).
- Extensible optional local-model setup (`docker-compose.ollama.yml`, `litellm-config.ollama.yaml`).
- **Why below top 2:** broader exposed surface (public LiteLLM port and permissive/wildcard passthrough behavior) increases security risk.

### 4) `exp-auto`
- Good practical baseline: healthchecks, straightforward startup paths, and decent onboarding.
- Has useful reverse-proxy controls in `Caddyfile`.
- **Why mid-pack:** fewer strict validation guardrails and some permissive defaults (notably around CORS/dev key conventions) lower production confidence vs top branches.

### 5) `exp-composer-2`
- Clean and workable single-stack setup with basic smoke tooling.
- **Why lower:** fewer hardening defaults and fewer operational guardrails; less modular than top branches.

### 6) `exp-gemini-3.1-pro` (Weakest)
- Functional minimal setup, but operationally thin.
- **Why last:** insecure defaults in production path (including dev-like master key fallback), direct service exposure, and sparse validation/hardening scaffolding.

## Final recommendation
Use **`exp-claude-opus-4-7-high`** as the baseline for the experiment outcome.

Immediate follow-up improvements:
1. enforce gateway auth defaults in production (`Caddyfile` + env wiring),
2. remove insecure fallback secrets from compose configs,
3. pin container image versions for reproducibility and safer upgrades.
