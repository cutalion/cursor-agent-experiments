# Experiment: joke-arena

**Purpose:** This experiment evaluates the ability of various AI models to build a "Joke Arena" Rails application. The application pits different LLMs against each other to generate jokes, allowing users to vote on the best one and maintaining a leaderboard. The goal is to assess each model's architectural choices, transactional correctness (especially around voting and scoring), third-party API integration (RubyLLM), and testing discipline.

👉 **[Read the Final Synthesized Results](RESULTS.md)**

## Run Configuration
- **Models**: gpt-5.5-high claude-opus-4-7-high composer-2 gemini-3.1-pro auto claude-4.6-sonnet-medium-thinking
- **Base Branch**: main
- **Prefix**: joke-arena
- **Plan File**: experiments/joke-arena/plan.md
- **Task Prompt**: default
- **Eval Prompt**: default

## Results
- [Analysis Results](RESULTS.md)
- [Verdicts](verdicts/)
- [Logs](logs/)

## Implementation Branches
- `joke-arena-gpt-5.5-high`
- `joke-arena-claude-opus-4-7-high`
- `joke-arena-composer-2`
- `joke-arena-gemini-3.1-pro`
- `joke-arena-auto`
- `joke-arena-claude-4.6-sonnet-medium-thinking`
