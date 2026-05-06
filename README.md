# LiteLLM Infra Experiments

## Overview

This repository is a focused playground for running automated LiteLLM infrastructure experiments with `cursor-agent`.

It is intentionally minimal and keeps only:
- `litellm_infra_plan.md` (requirements prompt)
- `scripts/run_experiment.sh` (automation entrypoint)

The goal is to run repeated model experiments in a clean, reproducible way with less manual branch orchestration.

## How This Repo Differs

The original `litellm-infra` repo used a branch-centric workflow for model implementations and comparisons.

This experiments repo is different:
- runs are orchestrated by `scripts/run_experiment.sh`
- implementation workspaces are created in `/tmp`
- prompt files are copied into those temporary workspaces
- execution is more automated and repeatable for multi-model runs

In short: this repo optimizes for automation and fast iteration.

## Workflow

1. Keep your requirements in `litellm_infra_plan.md` (or pass custom prompt files).
2. Run `scripts/run_experiment.sh` with one or more models.
3. The script creates isolated `/tmp` workspaces per model.
4. `cursor-agent` generates implementation output in each workspace.
5. Results are imported into git branches automatically.
6. Optional verdict generation can compare branches and write verdict files.

## Usage

Basic run:

```bash
scripts/run_experiment.sh --models gpt-5,sonnet-4
```

Run with verdicts:

```bash
scripts/run_experiment.sh --models gpt-5,sonnet-4 --with-verdicts
```

Inspect without mutating git:

```bash
scripts/run_experiment.sh --models sonnet-4 --dry-run
```

## Notes

- Temporary workspaces live under `/tmp` during execution.
- Use `--keep-tmp` if you want to inspect generated workspaces after the run.
- The script expects a clean working tree unless `--dry-run` is used.
- `cursor-agent` and `git` must be installed and available in your shell.
