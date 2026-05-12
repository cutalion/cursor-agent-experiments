# Joke Arena Verdict - gpt-5.5-high

Evaluator: `gpt-5.5-high`

## Overall Winner

The best implementation is **`joke-arena-claude-opus-4-7-high`**.

It is the most complete product implementation: a real Rails app with SQLite, ERB, Turbo/Stimulus, responsive CSS, config-driven competitor models, a RubyLLM wrapper, hidden model identities before voting, four vote outcomes, leaderboard stats, WebMock-backed deterministic tests, and strong documentation. Its biggest drawbacks are that it places the Rails app directly under `experiments/joke-arena` rather than `experiments/joke-arena/app`, lacks a committed `Gemfile.lock`, and has a few correctness edge cases around model sync and voting on non-generated comparisons. Even with those issues, it has the best balance of functional completeness, correctness, test breadth, documentation, and maintainability.

## Ranking

1. **`joke-arena-claude-opus-4-7-high`**
2. **`joke-arena-gpt-5.5-high`**
3. **`joke-arena-auto`**
4. **`joke-arena-claude-4.6-sonnet-medium-thinking`**
5. **`joke-arena-composer-2`**
6. **`joke-arena-gemini-3.1-pro`**

I inspected the branches with read-only git comparisons against `main`, focusing on `experiments/joke-arena`.

## Branch Assessments

### 1. `joke-arena-claude-opus-4-7-high`

This branch has the strongest architecture and coverage. It adds a full Rails 7.2 app with controllers for comparisons, votes, and leaderboard; persistent `CompetitorModel` records; service objects under `Arena`, `Llm`, and `Voting`; ERB views; Stimulus controllers; CSS; migrations/schema; fixtures; controller, integration, service, model, and system tests.

Concrete strengths:

- `app/services/llm/client.rb` wraps RubyLLM through `RubyLLM.chat`, passes `model`, `provider`, and `assume_model_exists`, extracts response content, applies timeouts, and maps provider/configuration failures to safe messages.
- `app/services/arena/joke_generator.rb` chooses two enabled models, creates a pending comparison, stores generated jokes, and records failed generation states instead of crashing.
- `app/services/voting/record_vote.rb` uses a transaction, compare-and-swap update on `vote_choice`, SQL increments, and duplicate-vote handling.
- Tests cover all vote choices, duplicate votes, failed comparisons, generation failures, leaderboard behavior, model config, system flow, and WebMock network blocking.
- README explains setup, provider credentials, config-driven models, scoring, tests, and troubleshooting.

Weaknesses:

- The Rails app is rooted at `experiments/joke-arena` instead of the requested `experiments/joke-arena/app`.
- No `Gemfile.lock` is present, so dependency reproducibility is weaker.
- `Voting::RecordVote` comments mention guarding `status == "generated"`, but the update condition only checks `vote_choice: nil`; it rejects failed comparisons but could score a pending comparison if directly posted.
- Config sync appears to upsert configured models but may not disable models removed from YAML.

Despite these issues, this branch is the most production-shaped and easiest to maintain.

### 2. `joke-arena-gpt-5.5-high`

This is also a strong implementation. It adds a Rails app with `JokeComparisonsController`, `LeaderboardsController`, `JokeComparison`, `ModelScore`, `ConfiguredModelRegistry`, `JokeGenerationService`, `RubyLlmJokeClient`, ERB views, Stimulus pending-state behavior, CSS, migrations/schema, and a focused Minitest suite.

Concrete strengths:

- `JokeGenerationService` validates prompts, requires two enabled models, generates one joke per model, stores both jokes, and converts provider failures into safe user-facing errors.
- `JokeComparison#apply_vote!` locks the comparison in a transaction, rejects duplicate votes, updates both models once, and covers first, second, both-good, and both-bad scoring.
- Tests cover prompt validation, disabled state with fewer than two models, generation success/failure, hidden model names, vote reveal, all scoring choices, duplicate vote protection, config loading, leaderboard, system flow, and WebMock isolation.
- README is concise and useful, including setup, credentials, model config, scoring, and test isolation.

Weaknesses:

- Like Opus, it places the Rails app directly under `experiments/joke-arena` rather than `experiments/joke-arena/app`.
- No `Gemfile.lock` is present.
- `ConfiguredModelRegistry` preserves extra model options, but `RubyLlmJokeClient` only passes `model` and `provider` to RubyLLM; this weakens support for custom/not-yet-known model identifiers that need options such as `assume_model_exists`.
- It is simpler than Opus: model configuration is not synced into first-class DB rows, and some error/status modeling is less explicit.

This branch is close to the winner, but Opus has broader production structure and a more complete RubyLLM/error boundary.

### 3. `joke-arena-auto`

This is a coherent smaller implementation. It adds Rails app files at `experiments/joke-arena`, uses `ArenasController` for prompt submission, `ComparisonsController#vote`, `Comparison#apply_vote!`, `ModelRegistry`, `JokeGenerator`, Turbo Stream views, CSS, controller/model/service/system tests, WebMock, and a practical README.

Concrete strengths:

- `ArenasController#create` handles blank prompts, fewer-than-two-models, generation failures, model selection, and Turbo/HTML responses.
- `Comparison#apply_vote!` transactionally locks the comparison, prevents duplicate votes, and updates both model stats exactly once for all four vote outcomes.
- `JokeGenerator` uses `RubyLLM.chat(...).ask`, extracts response text, and rejects blank responses.
- Tests cover prompt validation, generation success/failure, voting, duplicate protection, model registry, leaderboard, and a system flow; `test_helper` disables external network calls with WebMock.

Weaknesses:

- App is rooted at `experiments/joke-arena`, not `experiments/joke-arena/app`.
- No committed lockfile or schema was visible in the branch diff, which hurts reproducible onboarding.
- Test coverage is noticeably thinner than Opus/GPT, especially around all vote choices, RubyLLM contract behavior, config edge cases, leaderboard ordering, and failure modes.
- RubyLLM custom model support is basic; extra provider options are not represented.

It ranks ahead of Sonnet because its core voting/scoring path is simpler and more transactionally correct, even though Sonnet has better docs and layout.

### 4. `joke-arena-claude-4.6-sonnet-medium-thinking`

This branch deserves credit for following the requested layout: the Rails app lives under `experiments/joke-arena/app`. It also has strong onboarding docs, config-driven models, a RubyLLM wrapper, Turbo/Stimulus assets, model/vote/score records, and a broad test suite.

Concrete strengths:

- README clearly explains `cd experiments/joke-arena/app`, setup, credentials, model configuration, custom/local models, scoring, test isolation, and architecture.
- `ModelRegistry` reads `config/models.yml` with `identifier`, `display_name`, `provider`, `model_id`, `enabled`, and `assume_model_exists`.
- `JokeGenerator` uses `RubyLLM.chat`, applies instructions, supports `assume_model_exists`, handles blank responses, and sanitizes common secret-like error content.
- Tests use WebMock and stubs for `ModelRegistry`/`JokeGenerator`, including system coverage for the full flow.

Weaknesses:

- The vote/scoring boundary is not atomic enough. `VotesController#create` saves the vote first, then calls `ScoreUpdateService`, and rescues scoring failures without failing the request. If scoring fails after the vote is saved, the unique vote constraint prevents retrying and the leaderboard can remain permanently wrong.
- `JokeGenerator#build_chat` ignores the configured provider when constructing `RubyLLM.chat`, so provider/source configuration is not fully honored.
- No `Gemfile.lock` is present.
- Several tests rely on stubs and do not fully exercise the scoring failure/atomicity issue.

The exact directory layout and docs are strong, but the non-atomic vote/scoring behavior is too central to rank it above Auto.

### 5. `joke-arena-composer-2`

Composer produced a fairly complete Rails-shaped app with config-driven models, comparison/vote/leaderboard controllers, services for model catalog, LLM gateway, joke generation, and scoring, Turbo Stream vote responses, CSS, and many tests.

Concrete strengths:

- The product flow is mostly present: prompt, two model selection, stored jokes, hidden model names, four vote choices, results, and leaderboard.
- Tests cover many required behaviors on paper, including scoring edges, duplicate vote prevention, presentation, model catalog, and system flow.
- README covers setup, model config, credentials, scoring, testing, and troubleshooting.

Weaknesses:

- `Gemfile.lock` is a two-line placeholder, not a valid Bundler lockfile, which is a serious developer-experience and reproducibility problem.
- `config/environments/test.rb` enables CSRF protection; controller tests post without authenticity tokens, so the suite is likely to fail.
- RubyLLM integration in `JokeArena::LlmGateway` tries `RubyLLM::Chat.new` before `RubyLLM.chat`, which is less aligned with the documented interface and increases boot/runtime risk.
- Concurrent first-time stat creation can race around `find_or_initialize_by`.

It is more ambitious than Gemini, but the placeholder lockfile and likely failing tests keep it below the smaller, cleaner branches.

### 6. `joke-arena-gemini-3.1-pro`

Gemini is the thinnest implementation. It creates a minimal Rails app with `Comparison`, `LlmModel`, `JokeGenerator`, comparison/leaderboard controllers, views, migrations/seeds, and a few tests.

Concrete strengths:

- The basic product outline exists: model config/seed, prompt submission, two selected models, comparison page, four vote choices, duplicate guard, and leaderboard stats.
- Tests stub generation and use WebMock, so they are intended to avoid real LLM calls.
- README gives basic setup, credentials, model config, testing, and scoring information.

Weaknesses:

- RubyLLM usage appears weak or likely wrong, using a `RubyLLM::Client.new(...).chat(messages:)` style rather than the documented `RubyLLM.chat(...).ask` pattern used by stronger branches.
- Generation is handled with ad hoc threading and meta-refresh polling rather than a Rails job/Turbo flow; provider errors can become voteable placeholder joke text.
- Test coverage is minimal: it misses several required cases such as both-good, both-bad, generation failure, invalid votes, fewer-than-two models, config loading, leaderboard ordering, RubyLLM wiring, and high-level browser behavior.
- Hotwire/Stimulus usage is superficial, and maintainability is much weaker than the other branches.

It is a recognizable MVP scaffold, but it falls short of the production-ready Rails product requested by the spec.

## Final Recommendation

Use **`joke-arena-claude-opus-4-7-high`** as the winning implementation. If the goal is to merge or continue development, I would start from Opus and first fix the app placement question, add a real `Gemfile.lock`, tighten the vote status guard, and verify model sync behavior. `joke-arena-gpt-5.5-high` is the best fallback if a simpler codebase is preferred.
