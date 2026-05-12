# Joke Arena Verdict (model: auto)

## Final Ranking

1. **`joke-arena-claude-opus-4-7-high`** (best overall)
2. **`joke-arena-gpt-5.5-high`**
3. **`joke-arena-composer-2`**
4. **`joke-arena-auto`**
5. **`joke-arena-claude-4.6-sonnet-medium-thinking`**
6. **`joke-arena-gemini-3.1-pro`**

## Why `joke-arena-claude-opus-4-7-high` wins

`joke-arena-claude-opus-4-7-high` is the strongest blend of completeness, correctness, and engineering rigor:

- **Functional completeness:** Implements the full flow (prompt -> generation -> blind comparison -> vote -> reveal -> leaderboard), with explicit handling for `<2` enabled models and clear empty states.
- **Correctness:** Uses transaction-safe vote recording in `Voting::RecordVote` with a compare-and-swap style update (`where(id: ..., vote_choice: nil).update_all`) to prevent double-apply under race, plus deterministic score rules in `Voting::ScoreRules`.
- **RubyLLM integration quality:** `Llm::Client` wraps provider calls with timeout handling, error classification, and friendly user-facing messages while avoiding secret leakage.
- **Test quality:** Broad test surface (controllers, models, services, integration, system) and explicit test isolation (`WebMock.disable_net_connect!`, deterministic LLM stubbing helpers in `test/test_helper.rb`).
- **Documentation/onboarding:** Most complete README among the branches (setup, credentials, model config lifecycle, scoring, test strategy, troubleshooting).
- **Maintainability/DX:** Clear service boundaries (`Arena::*`, `Voting::*`, `Llm::*`) and coherent naming; easier to evolve safely than thinner or tightly coupled implementations.

## Per-branch assessment

### 1) `joke-arena-claude-opus-4-7-high`

**Strengths**
- Excellent coverage across required behaviors, including duplicate vote protection and friendly error paths.
- Strong operational docs and model configuration guidance.
- Good modular architecture and explicit scoring constants.

**Weaknesses**
- Like most branches, it also includes unrelated repository-wide deletions in the branch diff (outside the experiment scope), which is poor branch hygiene.

### 2) `joke-arena-gpt-5.5-high`

**Strengths**
- Very solid core correctness: row locking and transactional score updates in `JokeComparison#apply_vote!`.
- Good RubyLLM wrapper (`RubyLlmJokeClient`) and service-level error translation.
- Strong tests for scoring variants, duplicate-vote behavior, and no-network test isolation via WebMock.
- Clear README with practical setup/config/test instructions.

**Weaknesses**
- Slightly less depth than Opus in robustness and breadth of integration edge cases.
- Leaderboard and architecture are good but less extensible than Opus’s richer model registry + service layering.

### 3) `joke-arena-composer-2`

**Strengths**
- Full feature flow present, with duplicate protection via unique vote-per-comparison and transactional scoring.
- Good separation of concerns around `JokeArena::ScoringService`, `ModelCatalog`, and `LlmGateway`.
- README is clear and practical; test suite is fairly broad.

**Weaknesses**
- Some implementation choices are less clean for long-term maintainability (e.g., mixed asset strategy/CDN script loading and extra duplicated test concerns).
- Prompt/validation and flow correctness are good, but overall consistency/readability is below top two.

### 4) `joke-arena-auto`

**Strengths**
- Complete baseline implementation with required pages, blind voting, scoring, and leaderboard.
- Correct transactional vote logic in `Comparison#apply_vote!` with row locks.
- Clean, concise docs and model registry support.

**Weaknesses**
- Test depth is noticeably thinner than top branches (fewer edge-case and integration assertions).
- Error handling is more generic than best-in-class branches.

### 5) `joke-arena-claude-4.6-sonnet-medium-thinking`

**Strengths**
- Correctly places the Rails app under `experiments/joke-arena/app` (matching the spec’s preferred layout).
- Good README quality and many tests around score updates.

**Weaknesses (major)**
- `lib/joke_generator.rb` builds `RubyLLM.chat` without passing configured `provider`, undermining multi-provider correctness.
- `VotesController` persists the vote and then rescues score-update failures, which can leave vote state and leaderboard state inconsistent.
- Overall reliability of the transactional business flow is weaker than higher-ranked branches.

### 6) `joke-arena-gemini-3.1-pro`

**Strengths**
- Basic happy-path flow is implemented and documented.
- Uses WebMock in tests and provides a simple integration test.

**Weaknesses (major)**
- `JokeGenerator.generate_for` spawns a background thread and immediately redirects; this introduces racey UX/state behavior and weakens determinism.
- RubyLLM usage (`RubyLLM::Client.new ... chat`) appears inconsistent with the other branches’ safer documented chat wrapper style.
- Invalid vote/error handling and robustness are comparatively thin.
- Test coverage is significantly narrower than other branches.

## Criterion-by-criterion summary

- **Functional completeness:** Opus ~= GPT > Composer > Auto > Sonnet > Gemini
- **Correctness:** Opus > GPT > Auto ~= Composer > Sonnet > Gemini
- **Test quality:** Opus > GPT > Composer > Sonnet > Auto > Gemini
- **Documentation/onboarding:** Opus > Sonnet > GPT > Composer > Auto > Gemini
- **Developer experience:** Opus > GPT > Composer > Auto > Sonnet > Gemini
- **Maintainability:** Opus > GPT > Composer > Auto > Sonnet > Gemini

## Verdict

Pick **`joke-arena-claude-opus-4-7-high`** as the winning implementation. It has the best overall balance of product completeness, transactional correctness, RubyLLM integration quality, deterministic testing, and onboarding documentation, with fewer high-risk correctness concerns than the alternatives.
