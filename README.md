# AI Coding Experiments

This repository contains automated experiments comparing different AI models' coding and evaluation capabilities.

## Experiments

- [LiteLLM Infrastructure](experiments/litellm-infra/README.md): Models were tasked with implementing a production-ready LiteLLM API gateway infrastructure using Docker Compose and Caddy.
- [Joke Arena](experiments/joke-arena/README.md): Models are tasked with implementing a Rails, SQLite, Hotwire, and RubyLLM web app for comparing generated jokes and maintaining a leaderboard.

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
