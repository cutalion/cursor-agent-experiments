#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/run_experiment.sh [options] --models MODEL[,MODEL...]

Runs a LiteLLM infrastructure experiment with cursor-agent:
  1. Creates a fresh /tmp workspace per model containing only prompt files.
  2. Runs cursor-agent in headless print mode inside that workspace.
  3. Imports the result into an orphan git branch with no base-branch files.
  4. Optionally returns to the base branch and asks each model for a verdict.

Options:
  --models LIST          Comma-separated cursor-agent model names to run.
  --base BRANCH          Base branch for all experiment branches. Default: main.
  --name NAME            Name of the experiment (required). Used as the directory name in experiments/.
  --prefix PREFIX        Prefix for implementation branches. Default: experiment name.
  --task-prompt FILE     File containing the prompt template for the implementation task.
                         Defaults to experiments/<name>/task_prompt.md if present,
                         otherwise uses the built-in generic implementation prompt.
  --eval-prompt FILE     File containing the prompt template for the evaluation task.
                         Defaults to experiments/<name>/eval_prompt.md if present,
                         otherwise uses the built-in generic evaluation prompt.
  --plan FILE            Requirements plan file. Default: experiments/<name>/plan.md.
  --prompt-files LIST    Comma-separated files to seed into /tmp. Default: plan file.
  --keep-tmp             Keep /tmp workspaces after the run for inspection.
  --resume               Skip already completed implementations and verdicts.
  --keep-going           Continue with the next model if one fails.
  --with-verdicts        Also generate one verdict file per model on the base branch.
  --force-agent          Pass --force to cursor-agent so shell commands are allowed.
  --dry-run              Print commands without running cursor-agent or git mutations.
  --help                 Show this help.

Environment:
  CURSOR_API_KEY         Optional. cursor-agent can also use an existing login.

Examples:
  scripts/run_experiment.sh --models gpt-5,sonnet-4 --with-verdicts
  scripts/run_experiment.sh --name my-experiment --models sonnet-4 --dry-run

Notes:
  Implementation agents run in /tmp workspaces seeded only with prompt files.
  Verdict agents run in this repository so they can inspect git branches.

  cursor-agent usage checked locally:
    cursor-agent --print --model <model> --workspace <path> --trust [--force] "<prompt>"
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

trim() {
  printf '%s' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

copy_prompt_files() {
  local workspace="$1"
  local file

  for file in "${PROMPT_FILES[@]}"; do
    [[ -n "$file" ]] || continue
    [[ -f "$REPO_ROOT/$file" ]] || die "prompt file not found: $file"
    run mkdir -p "$workspace/$(dirname "$file")"
    run cp "$REPO_ROOT/$file" "$workspace/$file"
  done
}

copy_workspace_contents() {
  local src="$1"
  local dest="$2"

  if command -v rsync >/dev/null 2>&1; then
    run rsync -a --exclude .git "$src"/ "$dest"/
  else
    if [[ "$DRY_RUN" == "1" ]]; then
      printf '+ find %q -mindepth 1 -maxdepth 1 ! -name .git -exec cp -R {} %q ;\n' "$src" "$dest"
    else
      find "$src" -mindepth 1 -maxdepth 1 ! -name .git -exec cp -R {} "$dest" \;
    fi
  fi
}

cleanup_dir_contents() {
  local dir="$1"

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '+ find %q -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +\n' "$dir"
  else
    find "$dir" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  fi
}

branch_exists() {
  git show-ref --verify --quiet "refs/heads/$1"
}

parse_available_models() {
  sed -E '
    s/\r$//
    s/^[[:space:]]*[-*]?[[:space:]]*//
    s/^[[:space:]]*[0-9]+[.)][[:space:]]*//
    s/[[:space:]]+.*$//
    /^[[:alnum:]_.\/:-]+$/!d
    /^(Usage:|Options:|Commands:|No|Available|Model|Models)$/d
  '
}

validate_models() {
  local output
  local model
  local available_model
  local found
  local missing=()
  local available_models=()

  if ! output="$(cursor-agent --list-models 2>&1)"; then
    printf '%s\n' "$output" >&2
    die "failed to list cursor-agent models"
  fi

  while IFS= read -r available_model; do
    [[ -n "$available_model" ]] || continue
    available_models+=("$available_model")
  done < <(printf '%s\n' "$output" | parse_available_models)

  if [[ ${#available_models[@]} -eq 0 ]]; then
    printf '%s\n' "$output" >&2
    die "cursor-agent returned no available models"
  fi

  for model in "${MODELS[@]}"; do
    found="0"
    for available_model in "${available_models[@]}"; do
      if [[ "$model" == "$available_model" ]]; then
        found="1"
        break
      fi
    done

    if [[ "$found" != "1" ]]; then
      missing+=("$model")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'Requested unavailable cursor-agent model(s): %s\n' "${missing[*]}" >&2
    printf 'Available cursor-agent models:\n' >&2
    printf '  %s\n' "${available_models[@]}" >&2
    die "invalid --models list"
  fi

  log "validated cursor-agent models: ${MODELS[*]}"
}

sanitize_name() {
  local name="$1"
  name="${name// /-}"
  name="${name//_/-}"
  name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
  [[ -n "$name" ]] || die "model name '$1' cannot be converted to a branch-safe name"
  printf '%s' "$name"
}

verdict_file_name() {
  local name="$1"
  name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')"
  printf '%s/verdicts/%s_verdict.md' "$EXP_DIR" "$name"
}

has_changes() {
  [[ -n "$(git status --porcelain)" ]]
}

is_prompt_file() {
  local candidate="$1"
  local prompt_file

  for prompt_file in "${PROMPT_FILES[@]}"; do
    if [[ "$candidate" == "$prompt_file" ]]; then
      return 0
    fi
  done

  return 1
}

workspace_has_implementation_changes() {
  local workspace="$1"
  local file
  local rel

  while IFS= read -r -d '' file; do
    rel="${file#$workspace/}"
    if ! is_prompt_file "$rel"; then
      return 0
    fi
    if ! cmp -s "$REPO_ROOT/$rel" "$file"; then
      return 0
    fi
  done < <(find "$workspace" -type f ! -path "$workspace/.git/*" -print0)

  return 1
}

ensure_clean_tree() {
  if has_changes; then
    git status --short
    if [[ "$DRY_RUN" == "1" ]]; then
      log "dry run continuing despite uncommitted changes"
      return
    fi
    die "working tree has uncommitted changes; commit or stash them before running"
  fi
}

implementation_prompt() {
  local model="$1"
  local prompt_list="$2"
  
  if [[ -n "$TASK_PROMPT_FILE" ]] && [[ -f "$REPO_ROOT/$TASK_PROMPT_FILE" ]]; then
    # Read custom prompt and replace variables
    local content
    content="$(cat "$REPO_ROOT/$TASK_PROMPT_FILE")"
    content="${content//\$model/$model}"
    content="${content//\$prompt_list/$prompt_list}"
    printf '%s\n' "$content"
    return
  fi

  cat <<PROMPT
You are running a one-shot coding implementation experiment for model "$model".

You are in a fresh temporary workspace. The only seed files present are:
$prompt_list

Read the seed prompt/requirements files and implement the requested project from scratch in this workspace.

Requirements:
- Create all files needed to satisfy the experiment specification.
- Follow the required technology stack and constraints in the prompt files.
- Include configuration, documentation, tests, and helper scripts where useful.
- Do not inspect or copy files from any other repository or branch.
- Keep the result self-contained in this workspace.

When finished, summarize the files you created or changed and any commands you ran.
PROMPT
}

verdict_prompt() {
  local model="$1"
  local verdict_file="$2"
  local branches="$3"
  
  if [[ -n "$EVAL_PROMPT_FILE" ]] && [[ -f "$REPO_ROOT/$EVAL_PROMPT_FILE" ]]; then
    # Read custom prompt and replace variables
    local content
    content="$(cat "$REPO_ROOT/$EVAL_PROMPT_FILE")"
    content="${content//\$model/$model}"
    content="${content//\$verdict_file/$verdict_file}"
    content="${content//\$branches/$branches}"
    printf '%s\n' "$content"
    return
  fi

  cat <<PROMPT
You are evaluating a coding experiment as model "$model".

The implementation branches are:
$branches

Use git commands to inspect each branch. Compare the implementations against the experiment specification, including:
- functional completeness
- correctness
- test quality
- documentation and onboarding
- developer experience
- maintainability

Pick the best implementation, rank the others, and explain the reasoning with concrete evidence from the branches.
Write your final verdict to $verdict_file on the current branch. Do NOT commit the file, the wrapper script will commit it for you.
PROMPT
}

cleanup() {
  local exit_code=$?
  if [[ -n "${import_worktree:-}" ]] && [[ -d "$import_worktree" ]]; then
    git worktree remove --force "$import_worktree" 2>/dev/null || true
  fi
  if [[ "$exit_code" != 0 ]]; then
    log "Experiment failed or was interrupted. You can resume later with --resume."
  fi
  exit "$exit_code"
}
trap cleanup EXIT

MODELS_CSV=""
EXP_NAME=""
BASE_BRANCH="main"
PREFIX=""
PLAN_FILE=""
TASK_PROMPT_FILE=""
EVAL_PROMPT_FILE=""
PROMPT_FILES_CSV=""
WITH_VERDICTS="0"
FORCE_AGENT="0"
DRY_RUN="0"
KEEP_TMP="0"
RESUME="0"
KEEP_GOING="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --models)
      [[ $# -ge 2 ]] || die "--models requires a value"
      MODELS_CSV="$2"
      shift 2
      ;;
    --name)
      [[ $# -ge 2 ]] || die "--name requires a value"
      EXP_NAME="$2"
      shift 2
      ;;
    --base)
      [[ $# -ge 2 ]] || die "--base requires a value"
      BASE_BRANCH="$2"
      shift 2
      ;;
    --prefix)
      [[ $# -ge 2 ]] || die "--prefix requires a value"
      PREFIX="$2"
      shift 2
      ;;
    --task-prompt)
      [[ $# -ge 2 ]] || die "--task-prompt requires a value"
      TASK_PROMPT_FILE="$2"
      shift 2
      ;;
    --eval-prompt)
      [[ $# -ge 2 ]] || die "--eval-prompt requires a value"
      EVAL_PROMPT_FILE="$2"
      shift 2
      ;;
    --plan)
      [[ $# -ge 2 ]] || die "--plan requires a value"
      PLAN_FILE="$2"
      shift 2
      ;;
    --prompt-files)
      [[ $# -ge 2 ]] || die "--prompt-files requires a value"
      PROMPT_FILES_CSV="$2"
      shift 2
      ;;
    --with-verdicts)
      WITH_VERDICTS="1"
      shift
      ;;
    --keep-tmp)
      KEEP_TMP="1"
      shift
      ;;
    --resume)
      RESUME="1"
      shift
      ;;
    --keep-going)
      KEEP_GOING="1"
      shift
      ;;
    --force-agent)
      FORCE_AGENT="1"
      shift
      ;;
    --dry-run)
      DRY_RUN="1"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$MODELS_CSV" ]] || {
  usage
  die "--models is required"
}

[[ -n "$EXP_NAME" ]] || {
  usage
  die "--name is required"
}

EXP_DIR="experiments/$EXP_NAME"
if [[ -z "$PLAN_FILE" ]]; then
  PLAN_FILE="$EXP_DIR/plan.md"
fi
if [[ -z "$PREFIX" ]]; then
  PREFIX="$EXP_NAME"
fi
if [[ -z "$TASK_PROMPT_FILE" ]] && [[ -f "$EXP_DIR/task_prompt.md" ]]; then
  TASK_PROMPT_FILE="$EXP_DIR/task_prompt.md"
fi
if [[ -z "$EVAL_PROMPT_FILE" ]] && [[ -f "$EXP_DIR/eval_prompt.md" ]]; then
  EVAL_PROMPT_FILE="$EXP_DIR/eval_prompt.md"
fi

command -v git >/dev/null 2>&1 || die "git is required"
command -v cursor-agent >/dev/null 2>&1 || die "cursor-agent is required"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "must run inside a git repository"

REPO_ROOT="$(git rev-parse --show-toplevel)"
CURRENT_BRANCH="$(git branch --show-current)"
IFS=',' read -r -a MODELS <<< "$MODELS_CSV"
NORMALIZED_MODELS=()
for model in "${MODELS[@]}"; do
  model="$(trim "$model")"
  [[ -n "$model" ]] || continue
  NORMALIZED_MODELS+=("$model")
done
MODELS=("${NORMALIZED_MODELS[@]}")
if [[ -n "$PROMPT_FILES_CSV" ]]; then
  IFS=',' read -r -a PROMPT_FILES <<< "$PROMPT_FILES_CSV"
else
  PROMPT_FILES=("$PLAN_FILE")
fi

[[ ${#MODELS[@]} -gt 0 ]] || die "no models parsed from --models"
for prompt_file in "${PROMPT_FILES[@]}"; do
  [[ -f "$REPO_ROOT/$prompt_file" ]] || die "prompt file not found: $prompt_file"
done

validate_models
ensure_clean_tree

log "cursor-agent version: $(cursor-agent --version 2>/dev/null || printf 'unknown')"
log "repository: $REPO_ROOT"
log "base branch: $BASE_BRANCH"
log "prompt files: ${PROMPT_FILES[*]}"

AGENT_ARGS=(cursor-agent --print --trust)
if [[ "$FORCE_AGENT" == "1" ]]; then
  AGENT_ARGS+=(--force)
fi

IMPLEMENTATION_BRANCHES=()
TMP_ROOT="${TMPDIR:-/tmp}/litellm-infra-experiment-${PREFIX}-$$"
PROMPT_LIST=""
for prompt_file in "${PROMPT_FILES[@]}"; do
  PROMPT_LIST+="- $prompt_file"$'\n'
done

if [[ "$DRY_RUN" == "1" ]]; then
  printf '+ mkdir -p %q\n' "$TMP_ROOT"
else
  mkdir -p "$TMP_ROOT"
fi

for model in "${MODELS[@]}"; do
  safe_model="$(sanitize_name "$model")"
  branch="${PREFIX}-${safe_model}"
  workspace="$TMP_ROOT/workspace-$safe_model"
  import_worktree="$TMP_ROOT/import-$safe_model"
  IMPLEMENTATION_BRANCHES+=("$branch")

  log "starting implementation for $model in $workspace"

  if branch_exists "$branch"; then
    if [[ "$RESUME" == "1" ]]; then
      log "branch $branch already exists, skipping implementation for $model"
      continue
    else
      die "branch already exists: $branch (use --resume to skip)"
    fi
  fi

  run mkdir -p "$workspace"
  copy_prompt_files "$workspace"

  prompt="$(implementation_prompt "$model" "$PROMPT_LIST")"
  
  if ! run "${AGENT_ARGS[@]}" --workspace "$workspace" --model "$model" "$prompt" > "$workspace/agent_implementation.log" 2>&1; then
    log "error: cursor-agent failed during implementation for $model"
    cat "$workspace/agent_implementation.log"
    if [[ "$KEEP_GOING" == "1" ]]; then
      continue
    else
      die "cursor-agent failed"
    fi
  fi

  if [[ "$DRY_RUN" != "1" ]] && ! workspace_has_implementation_changes "$workspace"; then
    log "error: cursor-agent produced no implementation changes for $model in $workspace"
    if [[ "$KEEP_GOING" == "1" ]]; then
      continue
    else
      die "no changes produced"
    fi
  fi

  log "importing $workspace into orphan branch $branch"
  run git worktree add --detach "$import_worktree" "$BASE_BRANCH"
  run git -C "$import_worktree" checkout --orphan "$branch"
  run git -C "$import_worktree" rm -r --cached --quiet --ignore-unmatch .
  cleanup_dir_contents "$import_worktree"
  copy_workspace_contents "$workspace" "$import_worktree"

  if [[ "$DRY_RUN" != "1" ]] && [[ -z "$(git -C "$import_worktree" status --porcelain)" ]]; then
    log "error: nothing to commit after importing $workspace"
    run git worktree remove --force "$import_worktree"
    if [[ "$KEEP_GOING" == "1" ]]; then
      continue
    else
      die "nothing to commit"
    fi
  fi

  run git -C "$import_worktree" add .
  run git -C "$import_worktree" commit -m "Add $model $EXP_NAME implementation"
  run git worktree remove "$import_worktree"
done

run git checkout "$BASE_BRANCH"

if [[ "$WITH_VERDICTS" == "1" ]]; then
  branches_text=""
  for branch in "${IMPLEMENTATION_BRANCHES[@]}"; do
    branches_text+="- $branch"$'\n'
  done

  for model in "${MODELS[@]}"; do
    verdict_file="$(verdict_file_name "$model")"
    
    if [[ "$RESUME" == "1" ]] && [[ -f "$verdict_file" ]]; then
      log "verdict file $verdict_file already exists, skipping verdict for $model"
      continue
    fi

    log "starting verdict for $model into $verdict_file"
    prompt="$(verdict_prompt "$model" "$verdict_file" "$branches_text")"
    
    if [[ "$DRY_RUN" == "1" ]]; then
      printf '+ mkdir -p %q/logs %q/verdicts\n' "$EXP_DIR" "$EXP_DIR"
    else
      mkdir -p "$EXP_DIR/logs" "$EXP_DIR/verdicts"
    fi
    
    if ! run "${AGENT_ARGS[@]}" --workspace "$REPO_ROOT" --model "$model" "$prompt" > "$EXP_DIR/logs/${model}_verdict.log" 2>&1; then
      log "error: cursor-agent failed during verdict for $model"
      cat "$EXP_DIR/logs/${model}_verdict.log"
      if [[ "$KEEP_GOING" == "1" ]]; then
        continue
      else
        die "cursor-agent failed"
      fi
    fi

    if [[ "$DRY_RUN" != "1" ]] && [[ ! -f "$verdict_file" ]]; then
      log "error: cursor-agent did not create expected verdict file: $verdict_file"
      if [[ "$KEEP_GOING" == "1" ]]; then
        continue
      else
        die "missing verdict file"
      fi
    fi

    run git add "$verdict_file"
    if ! git diff --cached --quiet; then
      run git commit -m "Add $model verdict"
    fi
  done
fi

log "experiment complete"
log "started on branch: $CURRENT_BRANCH"
log "implementation branches: ${IMPLEMENTATION_BRANCHES[*]}"
if [[ "$WITH_VERDICTS" == "1" ]]; then
  log "verdict files committed on $BASE_BRANCH"
fi

if [[ "$DRY_RUN" != "1" ]]; then
  # Generate README.md for the experiment
  cat <<EOF > "$EXP_DIR/README.md"
# Experiment: $EXP_NAME

## Run Configuration
- **Models**: ${MODELS[*]}
- **Base Branch**: $BASE_BRANCH
- **Prefix**: $PREFIX
- **Plan File**: $PLAN_FILE
- **Task Prompt**: ${TASK_PROMPT_FILE:-default}
- **Eval Prompt**: ${EVAL_PROMPT_FILE:-default}

## Results
- [Analysis Results](RESULTS.md)
- [Verdicts](verdicts/)
- [Logs](logs/)

## Implementation Branches
EOF
  for branch in "${IMPLEMENTATION_BRANCHES[@]}"; do
    echo "- \`$branch\`" >> "$EXP_DIR/README.md"
  done
  
  run git add "$EXP_DIR/README.md"
  if ! git diff --cached --quiet; then
    run git commit -m "Add README for $EXP_NAME experiment"
  fi
fi

if [[ "$KEEP_TMP" == "1" ]]; then
  log "kept temp root: $TMP_ROOT"
else
  run rm -rf "$TMP_ROOT"
fi
