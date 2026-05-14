# AI Coding Experiments

This repository runs head-to-head experiments where multiple AI coding models tackle the same engineering brief from an identical starting point. Each model produces an implementation on its own branch, and the resulting code is then judged by the same set of models acting as evaluators. The goal is to compare not just raw output quality, but architectural choices, correctness under edge cases, testing discipline, and the models' ability to critique each other's work.

All runs go through the [Cursor CLI](https://docs.cursor.com/en/cli/overview) (`cursor-agent`). Two reasons:

1. It lets us pick the model per run, which is convenient given some leftover Cursor usage/credits.
2. It keeps the agent harness — and therefore the system prompt — identical across models. Running the same prompt through different agents (Claude Code, Codex, etc.) would change the environment each model sees, making the comparison apples-to-oranges. Using one agent isolates the model as the variable under test.

Each experiment ships with a plan, per-model implementation branches, individual verdicts, and a synthesized `RESULTS.md` summarizing the comparison.

## Experiments

- [LiteLLM Infrastructure](experiments/litellm-infra/README.md): Models build a production-ready LiteLLM API gateway stack using Docker Compose and Caddy — exercising infra-as-code skills, TLS/reverse-proxy configuration, and operational concerns like secrets handling and health checks.
- [Joke Arena](experiments/joke-arena/README.md): Models build a Rails + SQLite + Hotwire + RubyLLM web app that pits LLM-generated jokes against each other with voting and a leaderboard — exercising application architecture, transactional correctness around voting/scoring, third-party API integration, and test coverage.

Both experiments are run against the same model lineup: `gpt-5.5-high`, `claude-opus-4-7-high`, `claude-4.6-sonnet-medium-thinking`, `composer-2`, `gemini-3.1-pro`, and `auto`.

## Highlights from the runs so far

Full breakdowns live in each experiment's `RESULTS.md`. A few cross-cutting observations:

- **The same two models lead both experiments.** `claude-opus-4-7-high` and `gpt-5.5-high` finished 1st and 2nd in both runs. In LiteLLM Infra they tied for first (average rank 1.50 each); in Joke Arena, Opus was the unanimous winner with GPT-5.5 the unanimous runner-up. The remaining four models clustered in the middle, except for one consistent loser.
- **Opus and GPT-5.5 optimize for different things.** On the infra task, GPT-5.5 produced the *safest* baseline (fail-fast secrets via Compose `:?` guards, Caddy-only public surface, hardened headers), while Opus produced the *most complete* one (Postgres/Redis/Ollama profiles, log-rotation anchors, Makefile, deep smoke tests) but with permissive secret defaults. Multiple evaluators independently described the ideal output as "GPT's security posture + Opus's breadth."
- **`gemini-3.1-pro` finished dead last in both experiments — unanimously.** Every evaluator (including Gemini itself) ranked it 6th. Failures were concrete and severe: in Joke Arena, incorrect RubyLLM API usage that wouldn't run in production and persisting "Failed to generate joke" as a voteable entry; in LiteLLM, an insecure `default-master-key` fallback, exposing LiteLLM directly on host port 4000, `--detailed_debug` enabled in prod compose, and a hardcoded `example.com` in the Caddyfile.
- **Cross-model evaluation was surprisingly objective.** Self-bias was minimal across the board. Gemini ranked itself last in both experiments. Opus ranked GPT-5.5 above itself on the infra task. The only model that ranked itself first was GPT-5.5 on the infra task — and half the field independently agreed, so it reads as honest assessment rather than favoritism. `composer-2` was the lone exception, showing a mild self-favor in Joke Arena (ranked itself #3 vs. peer median #5).
- **Spec adherence ≠ winning.** In Joke Arena, `claude-4.6-sonnet-medium-thinking` was the *only* model that correctly placed the Rails app in `app/` per the spec — and still finished 3rd, because it had an atomicity bug (saving a vote before updating scores, swallowing scoring errors) that could permanently desync the leaderboard. Evaluators consistently weighed transactional correctness above literal directory-layout compliance.
- **The hard parts cluster around state and secrets.** Across both experiments the differentiators were concurrency correctness (atomic vote updates, SQL-arithmetic score increments) and secret handling (fail-fast vs. permissive defaults, host-port exposure of internal services). Pretty UIs and broad feature sets didn't move the needle when these were wrong.

## How to run an experiment

Use the `run_experiment.sh` script to generate implementations and verdicts:

```bash
./scripts/run_experiment.sh \
  --name my-experiment \
  --models gpt-5.5-high,claude-opus-4-7-high \
  --plan experiments/my-experiment/plan.md \
  --with-verdicts
```

Then use the `analyze_verdicts.sh` script to synthesize the results:

```bash
./scripts/analyze_verdicts.sh my-experiment
```
