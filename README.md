# trust-factory

**An agent workflow that measures how much you can trust it.**

> **Status:** Phases 0 to 3. The check script, the builder, the verifier and the trust suite exist, and offline tests check them (`tests/run.sh`). The builder opened its first draft PR on the pilot repo. The orchestrator does not exist yet. The full design is in [`docs/design.md`](docs/design.md).

trust-factory is a small Claude Code workflow for GitHub repos. A person marks an issue as ready. A builder agent makes the change in its own worktree and opens a draft PR. Fixed checks run first. Then a verifier agent, which cannot edit code, connects each acceptance criterion to evidence. Every run writes a record, and a seeded test suite measures how well the verifier finds bad PRs.

## Why

Many agent workflows show that agents can open PRs. Few of them show how often their own "pass" is correct. trust-factory makes that number visible:

- **Verifier scorecard:** seeded bad PRs and good PRs give a catch rate and a false-fail rate.
- **Fixed checks first:** new tests must fail without the change and pass with it. Each acceptance criterion must link to evidence.
- **Run ledger:** each issue records time, tokens, attempts, results and human edits.

## Progress

| Phase | Goal | Status |
|---|---|---|
| 0 | Decisions and pilot setup | Done |
| 1 | Check script and result format | In progress |
| 2 | Builder agent | Done |
| 3 | Verifier agent and trust suite | Done |
| 4 | Orchestrator and run ledger | Not started |
| 5 | Measure on ten real issues | Not started |
| 6 | Publish | Not started |

The latest trust suite result is in [`trust-suite/scorecard.md`](trust-suite/scorecard.md): the verifier caught 5 of 5 seeded bad PRs and passed 3 of 3 good controls.

## Inspiration

These projects and articles gave ideas. trust-factory uses none of their code.

- [super-board](https://github.com/EricTechPro/super-board) by Eric Tech: a board-driven build, check and merge loop, and the rule to verify the exact commit against the current base.
- [How to Run a Gauntlet Loop](https://somethingbig.ai/gauntlet-loop) by Matt Shumer: the builder never grades its own work, and the critic inspects the real output.
- [Harness Engineering for Self-Improvement](https://lilianweng.github.io/posts/2026-07-04-harness/) by Lilian Weng: keep the evaluator outside the editable surface.
- [Grok Ship](https://x.com/kunchenguid/status/2090463366762676732) by Kun Chen: fresh-context adversarial review.
- [AI-native workshop](https://github.com/workos/aie-ai-native-workshop) by WorkOS: goals and verification gates.
- [ai-tasks](https://github.com/onishimura/ai-tasks): my earlier plain-file task system for coding agents.
