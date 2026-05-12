# Joke Arena Verdict - gemini-3.1-pro

Evaluator: `gemini-3.1-pro`

## Overall Winner

The best implementation is **`joke-arena-claude-opus-4-7-high`**.

This branch provides the most robust, maintainable, and correct implementation. It correctly handles the complex atomicity requirements of voting and scoring, fully integrates with the `ruby_llm` gem as specified, and includes a comprehensive, deterministic test suite that isolates external network calls.

## Ranking

1. **`joke-arena-claude-opus-4-7-high`**
2. **`joke-arena-gpt-5.5-high`**
3. **`joke-arena-claude-4.6-sonnet-medium-thinking`**
4. **`joke-arena-auto`**
5. **`joke-arena-composer-2`**
6. **`joke-arena-gemini-3.1-pro`**

## Detailed Branch Assessments

### 1. `joke-arena-claude-opus-4-7-high`
- **Functional Completeness**: Implements all required features (prompt entry, joke generation, voting, leaderboard) with a polished UI.
- **Correctness**: Flawless handling of vote atomicity. `Voting::RecordVote` uses a compare-and-swap `update_all` for the vote choice, combined with SQL arithmetic (`score = score + ?`) for model stats within the same transaction. This perfectly satisfies the duplicate vote protection and atomic scoring requirements.
- **Test Quality**: Exceptional. It includes tests for all vote choices, duplicate vote race-safety, generation failures, and a full Capybara system test. It correctly stubs `Llm::Client` and uses WebMock to prevent external calls.
- **Maintainability & DX**: Excellent service-layer architecture (`Llm::Client`, `Arena::JokeGenerator`, `Voting::RecordVote`). The `RubyLLM` integration correctly passes `model`, `provider`, and `assume_model_exists`.
- **Weaknesses**: The Rails app is rooted at `experiments/joke-arena/` instead of `experiments/joke-arena/app/`, and it lacks a `Gemfile.lock`.

### 2. `joke-arena-gpt-5.5-high`
- **Functional Completeness**: Complete feature set with a clean UI using a Stimulus `pending` controller for the generation loading state.
- **Correctness**: Strong transactional integrity. `JokeComparison#apply_vote!` uses `lock!` and `with_lock` on the `ModelScore` records to prevent double-application of votes.
- **Test Quality**: Thorough Minitest suite covering all vote choices, duplicate votes, and generation failures.
- **Maintainability & DX**: Clean architecture with `JokeGenerationService` and `ConfiguredModelRegistry`. However, its `RubyLLM` integration is slightly weaker as it doesn't pass `assume_model_exists`.
- **Weaknesses**: Rooted at `experiments/joke-arena/` instead of `experiments/joke-arena/app/`.

### 3. `joke-arena-claude-4.6-sonnet-medium-thinking`
- **Functional Completeness**: Full feature set and the only branch that correctly places the Rails app in `experiments/joke-arena/app/`.
- **Correctness**: **Critical atomicity flaw.** `VotesController#create` saves the vote and then calls `ScoreUpdateService` inside a `begin/rescue` block that swallows errors. If scoring fails, the vote is recorded but scores are not updated, violating the spec.
- **Test Quality**: Good coverage, including a dedicated `ScoreUpdateService` suite and Capybara system tests.
- **Maintainability & DX**: Excellent documentation (README) and clean directory layout.
- **Weaknesses**: The atomicity bug is a major correctness issue. It also fails to pass `provider:` to `RubyLLM.chat`.

### 4. `joke-arena-auto`
- **Functional Completeness**: Implements the core requirements with a nice Turbo Stream integration for replacing the form with the comparison view.
- **Correctness**: Correctly handles vote atomicity using `lock!` and `ModelStat.lock.find_by!` within a transaction.
- **Test Quality**: Solid test suite covering the core voting paths and a system flow.
- **Maintainability & DX**: Simple and coherent architecture.
- **Weaknesses**: Models are referenced by string slugs rather than foreign keys, no `assume_model_exists` support, and the leaderboard hides historical activity for disabled models.

### 5. `joke-arena-composer-2`
- **Functional Completeness**: Good product flow with Turbo Stream responses and Stimulus controllers.
- **Correctness**: **Race condition in scoring.** `ScoringService#bump` uses `ModelStat.lock.find_or_initialize_by`, which only locks on the SELECT path. Concurrent first votes for a model can race on the unique index.
- **Test Quality**: Extensive test suite, but the test environment configuration (`config.action_controller.allow_forgery_protection = true`) causes controller tests to fail due to missing authenticity tokens.
- **Maintainability & DX**: Good service objects (`LlmGateway`, `ScoringService`), but the `Gemfile.lock` is a placeholder, which hurts reproducibility.

### 6. `joke-arena-gemini-3.1-pro`
- **Functional Completeness**: Very minimal implementation. It uses a `meta refresh` tag for polling, which is fragile.
- **Correctness**: Uses `LlmModel.update_counters` which is atomic, but the `RubyLLM` integration is incorrect (`RubyLLM::Client.new` instead of `RubyLLM.chat`), meaning real provider calls would fail.
- **Test Quality**: Barebones. Only two unit tests and one integration test, missing coverage for most edge cases and failure modes.
- **Maintainability & DX**: Lacks standard Rails conventions (CSS is inline, no `Gemfile.lock`, models loaded via `db/seeds.rb` instead of dynamic config reading).
- **Weaknesses**: The incorrect `RubyLLM` usage and synchronous `Thread.new` generation make this the weakest implementation.
