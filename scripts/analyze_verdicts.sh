#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

MODEL1="claude-opus-4-7-high"
MODEL2="gpt-5.5-high"
FINAL_MODEL="gemini-3.1-pro"

echo "==> Running cross-verdict analysis pipeline..."

shopt -s nullglob
VERDICT_FILES=(*_verdict.md)
shopt -u nullglob

if [[ ${#VERDICT_FILES[@]} -eq 0 ]]; then
  echo "Error: No *_verdict.md files found in the repository root."
  exit 1
fi

echo "Found ${#VERDICT_FILES[@]} verdict files: ${VERDICT_FILES[*]}"

# Phase 1: First intermediate analysis
echo "==> Phase 1: Generating intermediate report using $MODEL1..."
cat <<PROMPT > /tmp/analyze_prompt_1.txt
You are an expert AI evaluator analyzing the results of a coding experiment.

Your task:
1. Read all the *_verdict.md files in this directory.
2. Synthesize a comprehensive comparison of all the verdicts.
3. Identify which model's implementation was generally considered the best across the different verdicts.
4. Highlight interesting facts, such as:
   - Consensus vs. disagreements among the evaluators.
   - Did models prefer their own implementations (self-bias) or were they objective?
   - What specific features made the winning implementations stand out?
5. Write this analysis to a new file named tmp_report_1.md.

Do NOT update README.md or RESULTS.md. Do not commit any files.
PROMPT

cursor-agent --print --model "$MODEL1" --workspace "$REPO_ROOT" --trust "$(cat /tmp/analyze_prompt_1.txt)"

# Phase 2: Second intermediate analysis
echo "==> Phase 2: Generating intermediate report using $MODEL2..."
cat <<PROMPT > /tmp/analyze_prompt_2.txt
You are an expert AI evaluator analyzing the results of a coding experiment.

Your task:
1. Read all the *_verdict.md files in this directory.
2. Synthesize a comprehensive comparison of all the verdicts.
3. Identify which model's implementation was generally considered the best across the different verdicts.
4. Highlight interesting facts, such as:
   - Consensus vs. disagreements among the evaluators.
   - Did models prefer their own implementations (self-bias) or were they objective?
   - What specific features made the winning implementations stand out?
5. Write this analysis to a new file named tmp_report_2.md.

Do NOT update README.md or RESULTS.md. Do not commit any files.
PROMPT

cursor-agent --print --model "$MODEL2" --workspace "$REPO_ROOT" --trust "$(cat /tmp/analyze_prompt_2.txt)"

# Phase 3: Final synthesis
echo "==> Phase 3: Synthesizing final results using $FINAL_MODEL..."
cat <<PROMPT > /tmp/analyze_prompt_final.txt
You are an expert AI evaluator. Two other AI models have already analyzed a set of coding experiment verdicts and produced their own intermediate reports:
- tmp_report_1.md (Analysis by $MODEL1)
- tmp_report_2.md (Analysis by $MODEL2)

Your task:
1. Read ONLY these two intermediate reports (tmp_report_1.md and tmp_report_2.md). Do NOT read the original *_verdict.md files.
2. Synthesize these two reports into a final, definitive analysis. You should ONLY rely on the findings from the two reports, do not make your own independent analysis of the original verdicts.
3. Write this final synthesized analysis to a new file named RESULTS.md.
4. Update the README.md file to:
   - Briefly explain the purpose of this repository (an experiment comparing different AI models' coding and evaluation capabilities for a LiteLLM infrastructure task).
   - Include a prominent link to the RESULTS.md file.

Do not commit the changes, just create/update the files.
PROMPT

cursor-agent --print --model "$FINAL_MODEL" --workspace "$REPO_ROOT" --trust "$(cat /tmp/analyze_prompt_final.txt)"

echo "==> Cleaning up temporary reports..."
rm -f tmp_report_1.md tmp_report_2.md /tmp/analyze_prompt_1.txt /tmp/analyze_prompt_2.txt /tmp/analyze_prompt_final.txt

echo "==> Analysis complete. Please review RESULTS.md and README.md."
