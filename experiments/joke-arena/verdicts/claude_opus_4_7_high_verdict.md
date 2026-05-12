# Joke Arena Verdict - claude-opus-4-7-high

Evaluator: `claude-opus-4-7-high`

## Overall Winner

The best implementation is **`joke-arena-claude-opus-4-7-high`**.

It has the cleanest service-layer architecture (`Llm::Client`, `Arena::JokeGenerator`, `Voting::RecordVote`, `Voting::ScoreRules`), the most rigorous voting/scoring path (compare-and-swap update plus SQL increment arithmetic), the most correct RubyLLM integration (passes `model`, `provider`, and `assume_model_exists`, and chains `with_instructions` properly), the broadest deterministic test suite (controller, service, model, integration, system, and a real RubyLLM-stub test), and a strong README. Its main blemishes — Rails app rooted at `experiments/joke-arena/` instead of `experiments/joke-arena/app/`, no `Gemfile.lock`, and a `Voting::RecordVote` guard that only checks `vote_choice: nil` rather than explicitly excluding `status == "pending"` — are real but minor compared to the structural and correctness issues in the other branches.

## Ranking

1. **`joke-arena-claude-opus-4-7-high`**
2. **`joke-arena-gpt-5.5-high`**
3. **`joke-arena-claude-4.6-sonnet-medium-thinking`**
4. **`joke-arena-auto`**
5. **`joke-arena-composer-2`**
6. **`joke-arena-gemini-3.1-pro`**

I evaluated branches by inspecting the diff against the spec commit and reading representative source/test files for each, focusing on the experiment directory.

## Branch Assessments

### 1. `joke-arena-claude-opus-4-7-high`

Strongest overall implementation: a complete Rails 7.2 app with controllers (`comparisons`, `votes`, `leaderboard`), `CompetitorModel`/`Comparison` records, service objects under `Arena`, `Llm`, and `Voting`, Stimulus controllers, accessible ERB views, fixtures, schema, migrations, and tests at every layer.

Concrete strengths:

- `app/services/llm/client.rb` calls `RubyLLM.chat(model:, provider:, assume_model_exists:)`, chains `chat = chat.with_instructions(system_prompt)`, applies a timeout, normalizes response text, and maps `Timeout`, auth, rate-limit, configuration, and provider errors to safe `Llm::Error` messages with reasons.
- `app/services/voting/record_vote.rb` does a compare-and-swap update: `Comparison.where(id:, vote_choice: nil).update_all(vote_choice:, voted_at:, status: "voted")`. Zero rows updated → duplicate path. Stats are then incremented with SQL arithmetic (`score = score + ?`, `comparisons_count = comparisons_count + 1`) inside the same transaction, so concurrent writers cannot lose updates.
- `app/services/voting/score_rules.rb` centralizes the four outcomes with constants (`WIN_POINTS = 3`, `TIE_GOOD_POINTS = 2`, `TIE_BAD_POINTS = -1`, `LOSS_POINTS = 0`); the leaderboard view renders these constants, so docs and behavior stay in sync.
- `app/services/arena/joke_generator.rb` picks two enabled models, creates a pending `Comparison`, calls `Llm::Client.generate` for each side, and either marks the comparison `"generated"` with both jokes or `"failed"` with a friendly `error_message`. Provider exceptions never reach the controller as raw stack traces.
- `Arena::ModelsConfig` validates YAML entries, upserts `CompetitorModel` rows on boot (`config/initializers/competitor_models.rb`), and preserves stats across config edits.
- `test/test_helper.rb` aliases the real `Llm::Client.generate`, installs a deterministic stub per test, exposes `with_llm_client(...)` to simulate provider failures, and wires `WebMock.disable_net_connect!(allow_localhost: true)`.
- Tests cover all four vote choices (`record_vote_test.rb`), duplicate vote race-safety, voting on a `failed` comparison, all-providers-down and one-provider-down failure paths (`joke_generator_test.rb`), `RubyLLM` argument passing including `assume_model_exists` (`llm/client_test.rb` swaps a `FakeRubyLLM` constant in), prompt validation and empty-state rendering (`comparisons_controller_test.rb`), leaderboard ordering and reveal-on-vote, and an end-to-end system test using the `rack_test` driver.
- README documents Ruby/Bundler/SQLite versions, `bin/setup`, config-driven model fields (including `assume_model_exists`), provider credentials, scoring rules, the test isolation contract (stubbed `Llm::Client` + WebMock), and troubleshooting.

Weaknesses:

- The Rails app is rooted at `experiments/joke-arena/` rather than the `experiments/joke-arena/app/` shown in `plan.md`. Only Sonnet follows the requested layout.
- No `Gemfile.lock` is committed, so reproducibility leans on the consumer running `bundle install`.
- `Voting::RecordVote` rejects `failed` comparisons explicitly but otherwise relies on `vote_choice: nil` as the only guard. A direct POST against a `pending` comparison (e.g., from a script before generation completes) would pass; in practice the generator runs synchronously so this isn't reachable through the UI.
- `Arena::ModelsConfig#sync_to_database!` upserts entries present in YAML but does not disable models removed from YAML. Stats survive, which is desirable, but a model can linger as `enabled: true` until manually disabled.

Despite those issues, this branch has the highest signal across functional completeness, correctness, test quality, documentation, and maintainability.

### 2. `joke-arena-gpt-5.5-high`

A focused, well-shaped implementation: `ConfiguredModelRegistry`, `RubyLlmJokeClient`, `JokeGenerationService`, `JokeComparison#apply_vote!`, `ModelScore`, ERB views with a Turbo frame, a Stimulus `pending` controller, migrations/schema, and a tight Minitest suite.

Strengths:

- `JokeComparison#apply_vote!` locks the row, returns early if `score_applied?`, then loads both `ModelScore` rows (with `with_lock`) and applies score deltas before flipping `score_applied: true` in the same transaction. The combined transaction + `score_applied` flag prevents double-application.
- `JokeGenerationService` validates the prompt, requires two enabled models, treats `RubyLlmJokeClient::ProviderError` as a safe `GenerationError`, and rejects blank model responses.
- Tests cover all four vote choices (`joke_comparison_test.rb`), duplicate-vote no-op, invalid choice, blank response, provider failure mapping to safe error, the empty state when fewer than two models are enabled, generation failure, hidden-then-revealed model names, leaderboard rendering, and a Capybara system flow.
- README is short but covers stack, setup, provider credentials, model config fields, scoring values, and test isolation.

Weaknesses:

- Same layout issue as Opus: app at `experiments/joke-arena/`, not `experiments/joke-arena/app/`.
- No `Gemfile.lock`.
- `RubyLlmJokeClient#build_chat` only passes `model:` and `provider:`. There is no `assume_model_exists` option, even though `ConfiguredModelRegistry::Model#options` retains the rest of the YAML — this weakens custom/not-yet-known model support that the spec calls out explicitly.
- The system prompt is concatenated into the user message instead of using `with_instructions`. Functional but less idiomatic than Opus/Sonnet.
- Parallel test runs combined with a cached registry (`Rails.cache.fetch`) and a `Rails.cache.clear` in setup is workable but slightly fragile; works in practice with the default `:null_store`.

This branch is a clean runner-up — its scoring is correct and its tests are thorough, but it's narrower in scope and slightly weaker on the RubyLLM contract.

### 3. `joke-arena-claude-4.6-sonnet-medium-thinking`

The only branch that places the Rails app at the requested `experiments/joke-arena/app/`. README is the most polished (TOC, model config examples, provider env table, architecture notes). Tests include a dedicated `ScoreUpdateService` suite and a Capybara system test under headless Chrome.

Strengths:

- Layout matches the plan tree: `experiments/joke-arena/app/{app,config,db,lib,test,...}`.
- `ModelRegistry` reads `identifier`, `display_name`, `provider`, `model_id`, `enabled`, and `assume_model_exists` from `config/models.yml`.
- `JokeGenerator` sanitizes error messages by stripping `sk-…` and `Bearer …` patterns before re-raising.
- `ScoreUpdateService` runs scoring inside a transaction with atomic `update_all("score = score + N", "wins = wins + 1", …)` and an explicit `comparisons_count = comparisons_count + 1` bump for both models.
- `Vote.validates :comparison_id, uniqueness:` plus a DB-level unique index on `votes.comparison_id` blocks duplicate votes.
- Tests cover scoring per choice, vote creation, duplicate rejection, invalid choices, turbo_stream rendering, model registry, system flow with hidden→revealed names.

Weaknesses (these are why it ranks below Opus and GPT despite stronger docs/layout):

- **Vote/scoring atomicity is broken.** `VotesController#create` saves the `Vote` first, then calls `ScoreUpdateService` and `rescue StandardError => e` swallows scoring failures with only a log line. The vote row remains, the comparison appears voted, but model scores are not updated — and the unique index on `votes.comparison_id` prevents retrying. This violates the spec's "Every completed vote updates both participating models' comparison counts exactly once" and "Score updates must be atomic and resistant to double submission."
- `JokeGenerator#build_chat` constructs `RubyLLM.chat(model: @model_config.model_id, assume_model_exists: …)` and never passes `provider:`. The configured provider is decorative — RubyLLM has to guess from the model id, which is unreliable for custom/local/openai-compatible deployments.
- `chat.with_instructions(SYSTEM_PROMPT)` is called but the return value is discarded (`chat = build_chat; chat.with_instructions(SYSTEM_PROMPT); response = chat.ask(prompt)`). Depending on RubyLLM's chat implementation (immutable builder vs. mutating accessor) the system prompt may simply be dropped.
- Tests `parallelize(workers: :number_of_processors)` and `ScoreUpdateService` calls `find_or_create_by!` on `ModelScore` without `lock`; in production, two concurrent first-ever votes for the same pair can race on the unique index for `model_identifier`.
- No `Gemfile.lock`.
- System tests require Chrome/Chromedriver.

If the atomicity bug were fixed and `provider:` were passed to `RubyLLM.chat`, this branch could legitimately compete for #1 because of its layout and docs. As shipped, the silent vote/score desync is too central to the spec to rank above branches that get it right.

### 4. `joke-arena-auto`

Coherent smaller implementation. Adds `ArenasController` (prompt + create with Turbo Stream), `ComparisonsController#vote`, `Comparison#apply_vote!`, `ModelRegistry`, `JokeGenerator`, ERB partials, a Stimulus loading controller, model/controller/service/system tests, and WebMock.

Strengths:

- `ArenasController#create` handles blank prompt, fewer-than-two-models, model selection, generation, and Turbo/HTML responses; catches `JokeGenerator::GenerationError` for friendly failure.
- `Comparison#apply_vote!` uses `lock!`, returns early on `voted?`, takes `ModelStat.lock.find_by!` row locks, applies score/win/loss/tie/bad counters, and bumps `comparisons_count` exactly once per side — all four vote outcomes are correct.
- `JokeGenerator` uses `RubyLLM.chat(model:, provider:).ask(prompt)` and rejects blank responses, raising `GenerationError` on failure.
- Tests cover all four vote choices (`comparison_test.rb`), duplicate vote, generation failure path, and a system flow that exercises `visit root_path → fill_in → click_button` end-to-end.
- README is short but covers stack, setup, model config, credentials, scoring, and test guarantees.

Weaknesses:

- Same `experiments/joke-arena/` vs `experiments/joke-arena/app/` placement issue.
- No `Gemfile.lock`.
- No `assume_model_exists` support; custom/not-yet-known model IDs aren't first-class.
- Models are referenced by string slug rather than a foreign key.
- Leaderboard filters `where(enabled: true)` and so hides historical activity for disabled models.
- No fixtures; less test coverage around prompt-length edge cases, RubyLLM contract behavior, and leaderboard ordering.
- `JokeGenerator#generate!` swallows `StandardError` (including `ArgumentError`) and re-raises as `GenerationError` with the raw message — better than crashing but provides less classification than Opus's `Llm::Client`.

A reasonable third-tier implementation that gets the core voting/scoring path right but is noticeably narrower than Opus/GPT/Sonnet.

### 5. `joke-arena-composer-2`

Composer ships a feature-complete-looking Rails app with `Comparison`, `Vote`, `ModelStat`, services under `JokeArena` (`LlmGateway`, `ModelCatalog`, `JokeGenerationService`, `ScoringService`, `Errors`), ERB views with Turbo Stream responses on vote, a Stimulus loading controller served from `public/stimulus_app.js`, migrations/schema, and many tests.

Strengths:

- Product flow is mostly in place: prompt → two models → stored jokes → hidden identities → four vote choices → result reveal → leaderboard.
- `Vote` enum, DB unique index on `votes.comparison_id`, and `rescue ActiveRecord::RecordNotUnique` give layered duplicate protection.
- `ScoringService` is transaction-scoped and uses `ModelStat.where(model_key: keys).lock.load` to take row locks before mutating.
- `LlmGateway` classifies provider errors into friendly messages (401/403 vs. 429 vs. timeout) and applies a configurable timeout.
- Tests cover the four vote choices, duplicate vote, invalid choice, generation failures, and a system flow.
- README is thorough: setup, RubyLLM config table, model config fields, scoring values, test isolation, troubleshooting.

Weaknesses:

- **`Gemfile.lock` is a two-line placeholder** ("Run `bundle install` in this directory to generate a full lockfile"). This is the worst onboarding/reproducibility signal in the set.
- **`config.action_controller.allow_forgery_protection = true` in `config/environments/test.rb`** combined with `protect_from_forgery with: :exception` in `ApplicationController`. `ActionDispatch::IntegrationTest` posts without authenticity tokens, so the controller tests are likely to raise `ActionController::InvalidAuthenticityToken`. The standard Rails test env defaults this to `false` for a reason.
- All entries in `config/joke_arena_models.yml` ship with `enabled: false`, so out of the box the app reports "Enable at least two models" and cannot generate jokes. (The test catalog `joke_arena_models_test.yml` does enable two, so tests aren't blocked.)
- `LlmGateway#build_chat` tries `RubyLLM::Chat.new(...)` first before falling back to `RubyLLM.chat(...)`. The documented gem surface is `RubyLLM.chat(...)`; reaching for `Chat.new` first is brittle to gem version changes.
- No `assume_model_exists` plumbing.
- `ScoringService#bump` does `ModelStat.lock.find_or_initialize_by(model_key:)`; `find_or_initialize_by` is `find_by(...) || new(...)`, so the `lock` only applies on the SELECT path. Two concurrent first votes for the same model can both miss and then race on the unique index.
- Hotwire/Turbo and Stimulus are loaded from jsDelivr in the layout — fine in dev, awkward to deploy in airgapped or strict-CSP environments.

Ambitious but undermined by the placeholder lockfile and the test-env CSRF setting; ranks above Gemini because the product surface is intact and the test/RubyLLM design is mostly defensible.

### 6. `joke-arena-gemini-3.1-pro`

The thinnest implementation. `Comparison`, `LlmModel`, `JokeGenerator`, `ComparisonsController` (with `new`/`create`/`show`/`vote`), `LeaderboardsController`, ERB views, a `db/seeds.rb` that loads `config/models.yml`, and a tiny test suite.

Strengths:

- The MVP outline is recognizable: prompt page, two-model selection, hidden→revealed model names, four vote choices, duplicate guard via `lock!` + `completed?` + `update_counters` (which is atomic).
- WebMock + a JokeGenerator monkey-patch keep tests offline.
- Integration test exercises prompt → comparison → vote → leaderboard.

Weaknesses:

- **RubyLLM usage is wrong.** `JokeGenerator#fetch_joke` instantiates `RubyLLM::Client.new(provider:, model:)` and calls `client.chat(messages: [...])`. The documented public API is `RubyLLM.chat(model:, provider:).ask(prompt)` — that's the pattern every other branch uses. Real provider calls would fail. The test suite passes only because the JokeGenerator class is monkey-patched.
- **Generation is run on `Thread.new`** with `ActiveRecord::Base.connection_pool.with_connection do ... end` and the comparison view polls via `<meta http-equiv="refresh" content="2">`. This isn't Hotwire/Turbo and is fragile under any meaningful traffic.
- **On error, "Failed to generate joke." is written into `joke_1`/`joke_2`**, so the placeholder text becomes a voteable joke that scores affect the leaderboard.
- Only two unit tests and one integration test. The required test list — both_good, both_bad, generation failure, invalid votes, fewer-than-two models, model configuration loading, leaderboard ordering, RubyLLM wiring, system flow — is largely missing.
- No `assume_model_exists`, no Stimulus controllers, very little CSS, no `Gemfile.lock`, no system test.

It's a recognizable starter, but it falls well short of the spec's "production-ready Rails web app" bar.

## Final Recommendation

Use **`joke-arena-claude-opus-4-7-high`** as the winning implementation. The branch most directly satisfies the plan's hard requirements: config-driven competitor models with RubyLLM provider/source/`assume_model_exists` support, atomic compare-and-swap voting with SQL increments, four vote outcomes with centralized scoring rules, hidden-then-revealed model identities, leaderboard with ranks/scores/stats, WebMock-isolated deterministic tests across controllers/services/models/integration/system, and clear setup docs. If continuing development, the first follow-ups should be: (a) decide between `experiments/joke-arena/` and `experiments/joke-arena/app/` and align with the plan tree, (b) commit a real `Gemfile.lock`, (c) tighten the `Voting::RecordVote` guard to require `status IN ("generated","voted")` rather than relying solely on `vote_choice IS NULL`, and (d) extend `Arena::ModelsConfig#sync_to_database!` to disable rows whose slug was removed from YAML. `joke-arena-gpt-5.5-high` is the best simpler fallback; `joke-arena-claude-4.6-sonnet-medium-thinking` is the best starting point if the priority is matching the requested directory layout and shipping with the most polished documentation, provided the vote/scoring atomicity bug is fixed first.
