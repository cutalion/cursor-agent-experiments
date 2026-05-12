# Verdict: joke-arena experiment
**Evaluator model**: claude-4.6-sonnet-medium-thinking

---

## Winner

**`joke-arena-claude-opus-4-7-high`**

It delivers the most complete, correct, and maintainable implementation across every dimension of the spec.

---

## Rankings

| Rank | Branch | Summary |
|------|--------|---------|
| 1 | `joke-arena-claude-opus-4-7-high` | Best in class: atomically correct voting, deepest test coverage, best documentation, most complete service layer |
| 2 | `joke-arena-gpt-5.5-high` | Clean and solid; second-best tests and docs; rack_test system tests are CI-friendly |
| 3 | `joke-arena-claude-4.6-sonnet-medium-thinking` | Correct repo layout (app/ subdir per spec); good tests and docs; hard Chrome dependency for system tests is the main weakness |
| 4 | `joke-arena-composer-2` | Good architecture and Turbo integration; blocked at first run by all models disabled; CDN-loaded frontend assets |
| 5 | `joke-arena-auto` | Working flow but missing `schema.rb`, syncs DB on every request, and has thin test coverage |
| 6 | `joke-arena-gemini-3.1-pro` | Severely under-tested (2 files), missing `capybara` and Stimulus gems, minimal documentation |

---

## Detailed Analysis

### 1. joke-arena-claude-opus-4-7-high (Winner)

**Functional completeness** — Full: prompt page, joke generation, comparison view, voting, leaderboard. Empty states for no-models and no-votes cases. `bin/setup` script included. Four model examples in `config/models.yml` (two enabled, two commented out with `assume_model_exists` examples).

**Correctness** — Duplicate vote protection is the most robust of all branches. It uses an atomic compare-and-swap `UPDATE WHERE vote_choice IS NULL` that returns 0 rows if already voted, rather than a read-check-then-write pattern. Score updates run as SQL increments inside the same transaction, avoiding read-modify-write races under concurrency. The `Voting::RecordVote` service separates business logic cleanly.

```ruby
# services/voting/record_vote.rb — atomic compare-and-swap
updated = Comparison.where(id: comparison.id, vote_choice: nil).update_all(
  vote_choice: @choice, voted_at: Time.current, status: "voted", ...
)
return Result.new(..., error_kind: DUPLICATE) if updated.zero?

# followed by SQL increments, not read-modify-write
CompetitorModel.where(id: model_id).update_all([
  "score = score + ?, wins = wins + ?, ...", delta.fetch(:score), ...
])
```

**Test quality** — 15 test files covering every spec requirement: prompt validation, generation success/failure, all four vote choices, duplicate vote, score updates, leaderboard ordering, model config loading, and a full system flow. The test helper installs a deterministic LLM stub in every test's `setup` and restores it in `teardown`; WebMock blocks all external HTTP. System tests use `rack_test` — no browser driver required.

**Documentation and onboarding** — Best README: markdown table for config fields, step-by-step setup with `bin/setup`, per-provider env vars, inline scoring table, troubleshooting section, and a project layout tree. The `config/models.yml` is also heavily commented inline. The README explicitly states that tests are fully offline and explains why.

**Developer experience** — `bin/setup` runs `bundle install`, `db:prepare`, and `db:seed` in one step. The `CompetitorModel` DB table is synced from YAML on boot via an initializer, so adding a model means editing YAML and restarting (or running `db:seed`) with no migration needed for the common case. `assume_model_exists` and `notes` fields support real-world usage.

**Maintainability** — Best service layer organization: `services/llm/` (client + error), `services/arena/` (generator + models config), `services/voting/` (record vote + score rules). Score constants live in `score_rules.rb`, which the leaderboard view reads directly to stay in sync. The `Llm::Client` handles timeout, auth, rate-limit, blank-response, and configuration errors with distinct error reasons and friendly messages.

---

### 2. joke-arena-gpt-5.5-high

**Functional completeness** — Full flow implemented. Per-environment model config (default/dev/test/prod) is the only branch to do this. Good scoring explainer in README.

**Correctness** — Duplicate vote protection uses a `score_applied` boolean with `lock!`. This is correct and safe for SQLite's serializable transactions. Score updates use `apply_delta!` with a sub-transaction row lock. The approach is slightly more fragile than a compare-and-swap UPDATE but is functionally correct.

**Test quality** — 7 test files; covers generation service, model config loading, voting in the model test, and a system flow. System tests use `rack_test` (no Chrome). Coverage is good but misses some spec requirements (no dedicated leaderboard test file, no explicit both-good/both-bad controller tests).

**Documentation** — Clear README with scoring table, env var instructions, and model YAML example. Slightly less thorough than claude-opus but still complete.

**Weaknesses** — No dedicated `Vote` model; vote fields live on `JokeComparison`. Minor but slightly reduces clarity.

---

### 3. joke-arena-claude-4.6-sonnet-medium-thinking

**Repo layout** — The only branch to correctly place the Rails app inside `experiments/joke-arena/app/` as the spec's repository layout diagram specifies.

**Functional completeness** — Full flow. Turbo Stream for vote reveal. Detailed leaderboard with scoring legend. Model config has commented-out examples for Gemini, OpenRouter, and local Ollama.

**Correctness** — Duplicate vote protection at two layers: model-level uniqueness validation and DB unique index on `votes.comparison_id`. The `ScoreUpdateService` uses atomic SQL (`update_all("score = score + N")`) for final increments, but first calls `find_or_create_by!` inside the transaction to ensure records exist — this `find_or_create_by!` can have a TOCTOU gap under high concurrency (two concurrent first-votes for a new model could both "not find" and both try to insert). For a low-traffic experiment this is acceptable.

**Test quality** — 9 test files; comprehensive coverage of all four vote choices at both service and controller levels; duplicate vote tests; score symmetry assertions; API-key-scrubbing test. System test requires headless Chrome (`driven_by :selenium, using: :headless_chrome`) — the only branch with this hard requirement, which breaks `bin/rails test:system` in any environment without Chrome installed. The README documents this requirement but it is still a friction point.

**Documentation** — Polished README with table of contents, provider table, scoring table, and inline commented model config examples. Slightly shorter on troubleshooting guidance than claude-opus.

**Weaknesses** — Chrome dependency for system tests is the clearest weakness. The leaderboard controller re-sorts the leaderboard array in Ruby after a DB query that could express the order with SQL directly. No `bin/setup` script.

---

### 4. joke-arena-composer-2

**Functional completeness** — Full flow. Good Turbo Streams with a dedicated `duplicate.turbo_stream.erb`. Separate test YAML (`config/joke_arena_models_test.yml`) keeps test models isolated. `Vote` enum model is clean.

**Correctness** — Duplicate vote protected at DB level (unique index) and caught via `ActiveRecord::RecordNotUnique` rescue. Score updates use `lock.load` + read-modify-write; safe under the lock but more verbose than needed.

**Biggest weakness** — `config/joke_arena_models.yml` ships with all three example models set to `enabled: false`. The app cannot run at all out of the box without manually editing this file. This violates the "Rails app boots and is immediately usable" expectation.

**CDN assets** — Turbo and Stimulus loaded from jsDelivr CDN. Acknowledged in README but means the app cannot run offline, and the CDN URL is a production dependency.

**Test quality** — Decent coverage but has duplicate test files (`test/models/scoring_service_test.rb` and `test/services/joke_arena/scoring_service_test.rb` appear to cover similar ground). Missing some spec-required test cases.

**Documentation** — Good README. Unusual scoring constants (10 win, 4 both-good, -3 both-bad) not well-motivated.

---

### 5. joke-arena-auto

**Functional completeness** — Core flow works. `ModelRegistry.sync_stats!` is called on every request to `ArenasController#index` and `#create`, writing to the DB on each page load — an inefficiency that would cause contention under any real load.

**Correctness** — `apply_vote!` uses `lock!` + read-modify-write (`model.update!(score: model.score + attrs[:score], ...)`). Safe under SQLite serialization but not optimal. Missing `schema.rb` means developers cannot use `db:schema:load`; they must run all migrations.

**Test quality** — 7 test files but shallow: the model registry test asserts `enabled.size >= 2` without controlling the YAML fixture, so it could pass or fail depending on config. No system test for generation failure, no explicit score symmetry tests, limited leaderboard coverage.

**Documentation** — Adequate README covering env vars, model config, scoring rules, and test guarantees.

---

### 6. joke-arena-gemini-3.1-pro (Last)

**Test quality** — Only 2 test files: `test/models/comparison_test.rb` (2 tests) and `test/integration/joke_arena_test.rb` (1 test). The integration test stubs `JokeGenerator` via `alias_method` in `setup` but never restores the original, which could leak between tests. No dedicated vote controller test, no leaderboard test, no generation failure test, no prompt validation test, no system test file.

**Missing Gemfile dependencies** — `capybara` is not in the Gemfile so `require "capybara"` in tests would fail. `stimulus-rails` and `importmap-rails` are absent; Stimulus is unavailable.

**Scoring** — Losing model receives `-1` for a win-loss outcome. While the spec says "choosing the first joke benefits the first model more than the second", assigning `-1` to the loser is a legitimate design choice, but it is inconsistent with the "both are bad" penalty (-1 each), meaning a loss is equivalent in points to a "both bad" outcome.

**Documentation** — Minimal: the README covers setup steps and model config at a high level but lacks troubleshooting, provider-level credential docs, and scoring details.

**WebMock** — Configured per-test inside each test's `setup` block (in `test_helper.rb`), meaning `WebMock.disable_net_connect!` is re-called on every test setup rather than once globally. Not incorrect, but unusual.

---

## Key Differentiators

| Criterion | claude-opus-4-7-high | gpt-5.5-high | claude-4.6-sonnet | composer-2 | auto | gemini |
|-----------|---------------------|-------------|-------------------|------------|------|--------|
| Atomic vote protection | ✅ compare-and-swap | ✅ lock+flag | ✅ DB unique index | ✅ DB unique index | ⚠️ lock+R-M-W | ⚠️ lock+R-M-W |
| Atomic score update | ✅ SQL increments | ✅ SQL increments | ✅ SQL increments | ⚠️ lock+save! | ⚠️ lock+save | ⚠️ update_counters |
| Test file count | 15 | 7 | 9 | 14 | 7 | 2 |
| System test driver | rack_test | rack_test | **Chrome required** | rack_test | rack_test | N/A |
| schema.rb committed | ✅ | ✅ | ✅ | ✅ | ❌ | N/A |
| Models enabled by default | ✅ | ✅ | ✅ | ❌ all disabled | ✅ | ✅ |
| bin/setup script | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| App in app/ subdir | ❌ | ❌ | ✅ (spec-compliant) | ❌ | ❌ | ❌ |
| No CDN dependency | ✅ | ✅ | ✅ | ❌ jsDelivr CDN | ✅ | ✅ |
