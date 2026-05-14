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
