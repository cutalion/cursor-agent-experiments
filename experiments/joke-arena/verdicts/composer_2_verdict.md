# Joke Arena experiment — evaluation (model: composer-2)

This verdict compares six implementation branches against `experiments/joke-arena/plan.md` and `experiments/joke-arena/README.md` (experiment goals). Evidence is from `git show <branch>:path` inspection; the evaluation environment did not successfully run `bundle` / `bin/rails test`, so pass/fail is inferred from code structure rather than executed suites.

## Executive summary

**Best implementation: `joke-arena-claude-opus-4-7-high`.**

It is the closest to a production-shaped Rails product: atomic, race-aware voting; clear service boundaries; YAML-driven models synced into the database without throwing away leaderboard history; strong documentation and onboarding; and tests wired for deterministic LLM boundaries plus WebMock.

---

## Final ranking (best → weakest)

1. **`joke-arena-claude-opus-4-7-high`**
2. **`joke-arena-gpt-5.5-high`**
3. **`joke-arena-composer-2`**
4. **`joke-arena-claude-4.6-sonnet-medium-thinking`**
5. **`joke-arena-auto`**
6. **`joke-arena-gemini-3.1-pro`**

---

## Criteria-driven comparison

### Functional completeness vs spec

| Branch | Assessment |
|--------|------------|
| **opus** | Main flow, four vote types, failed-generation path, leaderboard, config models, Turbo streams, Stimulus — all present in tree (`config/routes.rb`, `app/services/arena/`, `app/services/voting/`). |
| **gpt** | Same surface area with `JokeComparisonsController`, leaderboard, voting, Turbo frame on comparison (`app/views/joke_comparisons/show.html.erb`). |
| **composer-2** | Full flow with `VotesController`, Turbo stream responses, separate `Vote` model, leaderboard (`git` tree lists `comparisons_controller.rb`, `votes_controller.rb`, `leaderboard_controller.rb`). |
| **sonnet** | Feature-complete under `experiments/joke-arena/app/` (nested Rails root — see DX). |
| **auto** | Core UX present (`arenas_controller`, comparisons voting, leaderboard) but thinner surface than opus/gpt/composer. |
| **gemini** | Incomplete relative to spec: async `Thread` in `JokeGenerator.generate_for` risks showing jokes before generation finishes; `ruby_llm` usage via `RubyLLM::Client.new` does not match the integration style used elsewhere in this repo family; leaderboard/tests are minimal (`test/integration/joke_arena_test.rb` only scratches the flow). |

### Correctness (scoring, duplicate votes, blind comparison)

- **opus — strong.** `Voting::RecordVote` applies a compare-and-swap `update_all` on `vote_choice IS NULL`, then applies SQL score deltas in one transaction (`experiments/joke-arena/app/services/voting/record_vote.rb`). This directly targets “duplicate votes cannot double-apply” and concurrent updates. `Voting::ScoreRules` documents +3 / +0 win-loss economics consistent with the spec (`score_rules.rb`).

- **gpt — strong.** `JokeComparison#apply_vote!` locks the row, short-circuits when `score_applied?`, updates both `ModelScore` rows, then marks the comparison (`joke_comparison.rb`). Meets atomicity and duplicate protection by design.

- **composer-2 — strong.** Database uniqueness on votes plus `rescue ActiveRecord::RecordNotUnique` and transaction wrapping vote + scoring (`votes_controller.rb`, `scoring_service.rb` with `ModelStat.lock`).

- **sonnet — strong.** Separate `Vote` model, `ScoreUpdateService` using `update_all` arithmetic, README claims unique index on `votes.comparison_id` (consistent with spec intent).

- **auto — good.** `Comparison#apply_vote!` uses `lock!` and `voted?` guard; score deltas match the common +3 / +1 / −1 pattern (`comparison.rb`). Less defensive than opus’s CAS under theoretical races but acceptable for SQLite serialisation in many workloads.

- **gemini — incorrect vs spec.** On a win, the losing model’s **score is decremented** (`comparison.rb`: `LlmModel.update_counters(llm_model_2_id, score: -1, losses: 1, ...)` for a model_1 win). The spec requires the loser to fare worse than the winner, not necessarily a negative score delta when the opponent wins (other implementations use **+0** for the loser). README scoring repeats the inconsistent rules.

### Test quality and LLM isolation

- **opus — best breadth + harness.** `test/test_helper.rb` installs WebMock, aliases the real `Llm::Client.generate`, provides `with_llm_client`, and explains why parallel tests are disabled (global stub). Service-level tests exist for voting, LLM client, generator, config (`test/services/...`, `test/integration/full_flow_test.rb`, `test/system/arena_flow_test.rb`).

- **gpt — strong.** WebMock in `test_helper.rb`, fixture-based tests, dedicated service tests (`joke_generation_service_test.rb`, `configured_model_registry_test.rb`), system flow.

- **composer-2 — strong.** WebMock, helpers that stub `JokeArena::JokeGenerationService.call`, system test file present. Minor maintainability nit: duplicate-looking test paths (`test/models/scoring_service_test.rb` and `test/services/joke_arena/scoring_service_test.rb` both appear in the tree).

- **sonnet — strong** (under nested app): controller, model, service, system tests including duplicate vote and score assertions (`votes_controller_test.rb`).

- **auto — adequate but thinner.** Stubs `JokeGenerator` in controller/system tests; WebMock enabled. Missing many of the explicit edge-case suites present on opus/gpt (e.g. duplicate vote integration tests not observed in `comparisons_controller_test.rb`).

- **gemini — weak.** Integration test aliases `JokeGenerator.generate_for` only in `setup` without a matching teardown in the shown file (risk of polluting later tests if the suite grows). No evidence of the full vote-matrix coverage the spec lists. Claims stubbing in README are stronger than what the code shows.

### Documentation and onboarding

- **opus — strongest README** among branches: versions, `bin/setup` / `bin/dev`, env vars table, YAML schema table, scoring table aligned with `ScoreRules`, troubleshooting, explicit “tests do not call providers” section.

- **gpt — very good** README: models YAML by environment, credentials, scoring, testing notes — slightly less operational detail than opus (no Procfile/dev story).

- **composer-2 — good** README: provider table, separate test YAML path via `config.x.joke_arena_models_path`, scoring — notes CDN-loaded Hotwire scripts (works, but slightly off the “importmap/Stimulus gem” beaten path).

- **sonnet — excellent prose** but duplicates navigation cost (see DX).

- **auto — acceptable** but shorter; fewer tables and edge-case explanations.

- **gemini — weak / misleading** (README scoring disagrees with spec and with other branches’ interpretation).

### Developer experience and layout

- **gpt, opus, composer-2, auto** place the Rails app at `experiments/joke-arena/` with the conventional `app/` subdirectory — matches the experiment README’s expected layout.

- **sonnet** nests the full Rails app at `experiments/joke-arena/app/` (results in `app/app/views/...`). README documents `cd experiments/joke-arena/app`, but this is easy to miss and conflicts with other branches’ “just `cd experiments/joke-arena`” habit. Requires Chrome for system tests per README — higher friction than rack_test-first setups.

- **gemini** omits many scaffold conveniences present in other branches (`Gemfile.lock` absent in tree, sparse Rails skeleton), increasing setup risk.

### Maintainability

- **opus** wins on separation of concerns (`llm/`, `arena/`, `voting/`), I18n for errors, and database-backed registry that still honours YAML as source of truth (`config/initializers/competitor_models.rb` syncing after boot).

- **gpt** is clean and idiomatic ActiveRecord; slightly less layered than opus but easy to follow.

- **composer-2** namespaces services under `JokeArena::` — good — but CDN-based JS and duplicated tests suggest a bit less polish.

- **auto** keeps logic in models/controllers; workable for a demo, less evolvable than service-extracted designs.

- **gemini** mixes threading, questionable API usage, and schema enums that are harder to reason about (`Comparison` enum + `record_vote!` flow).

---

## Why `joke-arena-claude-opus-4-7-high` wins

Concrete differentiators:

1. **Concurrency-aware duplicate vote handling** without relying on a happy-path `if voted?` alone — the `WHERE id = ? AND vote_choice IS NULL` pattern in `Voting::RecordVote#call` is exactly the kind of idempotency the spec demands.

2. **Operational completeness**: `bin/setup`, `Procfile.dev`, `bin/dev`, comprehensive README tables, and boot-time YAML→DB sync that preserves stats (`Arena::ModelsConfig.sync_to_database!`).

3. **Test harness discipline**: WebMock plus an explicit, restorable stubbing strategy for `Llm::Client.generate` in `test/test_helper.rb`.

4. **UI/spec alignment**: `comparisons/show.html.erb` hides real model names before the vote (`Mystery model`), then reveals `public_label` after voting.

No branch is perfect: opus surfaces point values on vote buttons (via `ScoreRules` constants), which is not a model identity leak but might be more “meta” than some experiment runners expect — still within the spec’s spirit of understandable scoring.

---

## Verdict

Ship **`joke-arena-claude-opus-4-7-high`** as the reference-quality implementation. **`joke-arena-gpt-5.5-high`** and **`joke-arena-composer-2`** are honorable runners-up with strong correctness stories but slightly less holistic product polish. **`joke-arena-gemini-3.1-pro`** is not specification-complete and needs substantial rework on scoring, async generation, RubyLLM integration, and tests before it could be judged alongside the others.
