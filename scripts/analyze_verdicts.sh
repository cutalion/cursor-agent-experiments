#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

MODEL="${1:-claude-opus-4-7-high}"

echo "==> Running cross-verdict analysis using model: $MODEL"

shopt -s nullglob
VERDICT_FILES=(*_verdict.md)
shopt -u nullglob

if [[ ${#VERDICT_FILES[@]} -eq 0 ]]; then
  echo "Error: No *_verdict.md files found in the repository root."
  exit 1
fi

echo "Found ${#VERDICT_FILES[@]} verdict files: ${VERDICT_FILES[*]}"

cat <<PROMPT > /tmp/analyze_prompt.txt
You are an expert AI evaluator analyzing the results of a coding experiment.

In this repository, several AI models were tasked with implementing a LiteLLM infrastructure setup based on a plan.
Afterward, each model evaluated all the implementations and wrote a verdict file (e.g., *_verdict.md).

Your task:
1. Read all the *_verdict.md files in this directory.
2. Synthesize a comprehensive comparison of all the verdicts.
3. Identify which model's implementation was generally considered the best across the different verdicts.
4. Highlight interesting facts, such as:
   - Consensus vs. disagreements among the evaluators.
   - Did models prefer their own implementations (self-bias) or were they objective?
   - What specific features made the winning implementations stand out?
5. Write this analysis to a new file named RESULTS.md.
6. Update the README.md file to:
   - Briefly explain the purpose of this repository (an experiment comparing different AI models' coding and evaluation capabilities for a LiteLLM infrastructure task).
   - Include a prominent link to the RESULTS.md file.

Do not commit the changes, just create/update the files.
PROMPT

cursor-agent --print --model "$MODEL" --workspace "$REPO_ROOT" --trust "$(cat /tmp/analyze_prompt.txt)"

echo "==> Analysis complete. Please review RESULTS.md and README.md."
