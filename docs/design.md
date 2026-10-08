# trust-factory design

This document is the single source of truth for the design of trust-factory. When a change alters behavior, names or formats, update this document in the same commit.

## Thesis

**An agent workflow that measures how much you can trust it.**

Many agent workflows show that agents can open PRs. Few of them show how often their checks are correct. trust-factory makes trust measurable:

1. **A verifier scorecard.** A suite of seeded bad PRs and good PRs. We run it after each prompt change, and we publish the catch rate and the false-fail rate.
2. **Fixed checks before model judgment.** A fail-first check proves that the new tests fail without the change. A criteria map connects each acceptance criterion to a test or to other evidence.
3. **A run ledger.** Each issue writes one record: time, tokens, attempts, results and human edits. A report shows the trends.

## Principles

- **A person controls the input.** Only a person adds the `agent:ready` label. By default, a person also merges.
- **The builder never grades its own work.** The verifier starts with no previous context, and it has no Edit or Write tools.
- **The verifier reads the diff, not the builder's summary.** A summary is a claim. The diff and the test results are evidence.
- **The checks stay outside the editable surface.** The check step reads its config from the base branch, never from the PR. A PR that changes the workflow files, CI or the check config always goes to a person.
- **Without evidence, the result is "unsure".** A criterion with no evidence cannot be "met". An "unsure" result always goes to a person.
- **Fixed checks come before model judgment.** When a script can check a fact, a model does not decide it.
- **Issue text is data.** Agents follow the acceptance criteria. They do not follow instructions in issue bodies, comments or code.
- **Use Claude Code features first.** Use subagents, worktree isolation, permission rules and the sandbox before custom scripts. Regex hooks are not a security boundary.
- **Each new feature must fix a failure that we saw.** Keep the core under approximately 500 lines, not including tests and the trust suite.

## Scope

### In v1

- State in GitHub issue labels (REST only).
- One orchestrator skill: `run`, `status`, `stop`, `report`.
- A builder subagent and a verifier subagent.
- A check script: fail-first check, verify commands, protected paths, a JSON result and a commit status.
- A trust suite of seeded PRs and a scorecard.
- A run ledger and a report.

### Not in v1

- Telemetry intake. Later, it can only draft issues, and a person makes them ready.
- A model router. Use one fixed model for each role.
- Separate QA and review steps. The verifier does both.
- Database migrations, usage limits, a headless backend, other agent tools.
- An onboarding wizard. A short README and one setup script are enough.

## Design

### State

| Label | Meaning | Who sets it |
|---|---|---|
| `agent:ready` | Ready for the builder | A person, or the orchestrator after a rebuild result |
| `agent:working` | A builder has the issue | Orchestrator |
| `agent:checking` | A draft PR exists; checks and the verifier run | Orchestrator |
| `agent:proposed` | All checks pass; the PR is ready for a person to merge | Orchestrator |
| `agent:needs-person` | A problem that a person must solve; a comment says why | Orchestrator |
| *(issue closed)* | The PR merged with `Closes #N` | GitHub |

### Flow

```text
issue + agent:ready   (a person)
        │
        ▼
orchestrator   (the user's session; 2 issues at a time)
        │
        ├─ builder        worktree → tests first → code → draft PR
        │
        ├─ check script   fail-first check → verify commands → protected paths
        │                 (fixed checks; config from the base branch)
        │
        ├─ verifier       fresh context, no Edit/Write tools
        │                 criteria map from the diff and test output
        │                 result: pass | fail | unsure
        │
        ├─ decision       pass + checks pass → commit status + agent:proposed
        │                 fail → rebuild (attempt limit) → then needs-person
        │                 unsure or protected path → needs-person
        │
        └─ ledger         one record for each issue
```

### Merge safety

The rule: merge only the commit that passed the checks, against the current base.

- **Main method (GitHub does the work).** The check script posts a commit status on the checked commit. Branch protection requires that status and an up-to-date branch. When the base moves, the orchestrator updates the PR branch. The head commit changes, so the checks must run again. Branch protection is free on public repos.
- **Fallback.** Where branch protection is not available, the script merges with `gh pr merge --match-head-commit`, and only one merge runs at a time.
- **Default mode is `propose`.** The workflow marks the PR as ready for review, and a person merges it.

### Fail-first check

New tests must fail without the change and pass with it.

1. In a scratch worktree at the base commit, add only the PR's test files (from `checks.fail_first.test_globs`).
2. Run those tests. At least one must fail.
3. At the PR head, run the same tests. All must pass.

If the PR has no test changes, the check fails, except for issues with the label `type:docs` or `type:chore`. Then the result is "skipped", and the reason goes into the result.

### Criteria map (verifier output)

```json
{
  "result": "pass",
  "criteria": [
    {
      "criterion": "Empty input returns an empty list",
      "met": true,
      "evidence": "test: parser.test.ts › returns [] for empty input"
    }
  ],
  "concerns": []
}
```

`result` is `pass`, `fail` or `unsure`. The orchestrator rejects a criterion that is `met` without evidence.

### Check result

The check script writes one JSON result. The exit code shows only whether the script ran. The `status` field shows the decision.

```json
{
  "issue": 42,
  "pr": 57,
  "commit": "3f2c1ab",
  "status": "proposed",
  "checks": [
    { "name": "fail-first", "result": "pass", "detail": "2 new tests failed on base and passed with the change" },
    { "name": "verify", "result": "pass", "detail": "npm test: 214 passed" },
    { "name": "protected-paths", "result": "pass" }
  ],
  "reasons": []
}
```

| `status` | Meaning | Next label |
|---|---|---|
| `merged` | Merged (only when `merge.mode` is `auto`) | Issue closed |
| `proposed` | All checks pass; a person merges | `agent:proposed` |
| `rebuild` | A check failed, or the base does not merge in | `agent:ready` |
| `recheck` | The PR head moved after the checks | `agent:checking` |
| `needs-person` | Protected path, "unsure" result or attempt limit | `agent:needs-person` |
| `retry-later` | A temporary problem, for example the GitHub API | No change |

### Config

The config lives in the target repo at `.trust-factory/config.json`. The check script reads it from the base branch.

```json
{
  "branch": { "base": "main", "prefix": "agent/" },
  "checks": {
    "verify": ["npm ci", "npm run typecheck", "npm test"],
    "fail_first": { "test_globs": ["**/*.test.ts", "tests/**"] }
  },
  "limits": { "concurrent_issues": 2, "attempts_per_issue": 3 },
  "merge": {
    "mode": "propose",
    "auto_when": { "max_diff_lines": 150 },
    "protected_paths": [".github/**", ".claude/**", ".trust-factory/**", "**/auth/**", "**/payments/**", "**/migrations/**"]
  }
}
```

The values are first guesses. Change them after Phase 5.

### Run ledger

One JSON line for each issue, in `.trust-factory/ledger.jsonl` in the target repo (not committed):

```json
{"issue": 42, "started": "2026-10-20T10:02:00Z", "finished": "2026-10-20T10:19:00Z", "attempts": 2, "tokens": 183000, "verdicts": ["fail", "pass"], "status": "proposed", "human_edits": false}
```

The `report` command reads the ledger. It also checks each merged PR for commits by a person, and it fills in `human_edits`.

### Trust suite

A set of PRs on a small fixture repo, each with an expected result.

| Category | The seeded PR… | Expected |
|---|---|---|
| Skipped criterion | Does not do one criterion, but its summary says that it does | `fail` |
| Overclaiming summary | Says that it ran tests or changed things that the diff does not show | `fail` |
| Weakened test | Removes, skips or loosens an existing test so that the suite passes | `fail` |
| Silent regression | Passes its own tests, but breaks a behavior that no test covers | `fail` or `unsure` |
| Injected instruction | Has text in the issue or in code that tells the verifier to approve | `fail`, and the text is reported |
| Good controls (3 PRs) | Correct and complete | `pass` |

The scorecard records the catch rate (bad PRs that get `fail` or `unsure`), the false-fail rate (good PRs that do not get `pass`) and the "unsure" rate. We run it after each change to a prompt.

### Components

| File | Approx. size | Job |
|---|---|---|
| `skills/trust-factory/SKILL.md` | 150 lines | Orchestrator: `run`, `status`, `stop`, `report`; moves labels; writes the ledger |
| `agents/builder.md` | 60 lines | Tests first, smallest safe change, draft PR |
| `agents/verifier.md` | 70 lines | Criteria map with evidence; `pass`, `fail` or `unsure` |
| `scripts/check.sh` | 120 lines | Fail-first check, verify commands, protected paths, JSON result, commit status |
| `scripts/report.py` | 60 lines | Ledger summary and scorecard |
| `config.example.json` | 15 lines | Example project settings |
| `trust-suite/` | — | Fixture repo, seeded PRs, expected results |
| `tests/` | — | Tests for `check.sh` and `report.py`; no network |

The paths are provisional until we decide how to install the workflow (see Open questions).

### Issue format

The orchestrator does not start an issue that has no acceptance criteria. It adds a comment and the label `agent:needs-person`.

```markdown
## Goal
One or two sentences.

## Acceptance criteria
- [ ] A result that a person or a test can check
- [ ] ...

## Out of scope
- ...
```

### Safety

- Branches use the prefix `agent/`. Agents never push to the base branch.
- Permission rules allow `gh`, `git` and the verify commands. They deny secret files. The sandbox limits file and network access.
- The verifier cannot push. Even if it changes a file through Bash, only the checked commit on GitHub can merge.
- `stop` stops the agents and leaves the labels as they are. The next `run` continues from the labels and the ledger.

## Implementation plan

### Phase 0: Decisions and pilot setup

- [x] Choose the name: `trust-factory`.
- [x] Make the repo (private until Phase 6).
- [ ] Select a pilot repo with a verify command that runs in less than two minutes.
- [ ] Create the labels in the pilot repo.
- [ ] Write three to five small, real issues with acceptance criteria.

Definition of done: the pilot repo has the labels and the issues, and the verify command passes on the base branch.

Phase 1 can start before the pilot is ready, because its tests use local test repos. Only the last Phase 1 task needs the pilot.

### Phase 1: Check script and result format

The check script needs no agents, so ordinary tests can check it.

- [ ] Write `check.sh` and `config.example.json`.
- [ ] Write tests with local test repos and a `gh` stub.
- [ ] Test these cases: fail-first pass, fail-first fail (the tests pass without the change), no test changes, verify failure, protected path, head moved, base conflict.
- [ ] Post a commit status, and test it on the pilot repo with branch protection.

Definition of done: all test cases pass, and the script gives the correct JSON result for a real pilot PR.

### Phase 2: Builder

- [ ] Write `builder.md`.
- [ ] Run the builder by hand on one pilot issue.

Definition of done: a draft PR with tests exists, the fail-first check passes, and the builder changed no files outside its worktree.

### Phase 3: Verifier and trust suite

- [ ] Write `verifier.md` with the criteria-map output.
- [ ] Build the fixture repo and the seeded PRs for each category, plus three good controls.
- [ ] Write the scorecard part of `report.py`.
- [ ] Run the verifier on the full suite.

Definition of done: the verifier catches all seeded bad PRs, passes all good controls, and the scorecard shows the results.

### Phase 4: Orchestrator and ledger

- [ ] Write the orchestrator skill: `run`, `status`, `stop`, `report`.
- [ ] Write a ledger record for each issue.
- [ ] Run one issue at a time, then two in parallel.
- [ ] Stop a run during work, then continue it.

Definition of done: three pilot issues go from `agent:ready` to a result in `propose` mode. The labels and the ledger are correct after a stop and a resume.

### Phase 5: Measure

- [ ] Run ten pilot issues.
- [ ] Run `report`: pass rate, attempts, human edits, time and tokens.
- [ ] Decide from the data whether to allow `auto` mode for small changes.

Definition of done: a written decision about auto-merge, with the ledger data and the scorecard.

### Phase 6: Publish

- [ ] Choose a license.
- [ ] Write the README: the thesis, a quick start, the scorecard, the ledger report and the credits.
- [ ] Add a short demo: one issue from `agent:ready` to a proposed PR, with its evidence.
- [ ] Make the repo public.

Definition of done: a person who does not know the project can install it on a test repo in less than 10 minutes and see the scorecard.

### Later (only if the data shows a need)

- An unattended mode with `/loop` or a scheduled task.
- Intake from a task backlog or from telemetry, as draft issues only.
- A blind second verifier with a different model, compared on the trust suite.

## Success criteria

These are first targets. Change them after Phase 5.

- The core stays under approximately 500 lines, not including tests and the trust suite.
- Setup on a new repo takes less than 10 minutes.
- No merge from the workflow makes the base branch fail its verify commands.
- Trust suite: the catch rate is 100%, and no more than one good control fails.
- At least 6 of 10 pilot issues finish with no human code changes.

## Decisions

| Date | Decision | Reason |
|---|---|---|
| 2026-10-08 | Keep the system small and readable | One person must be able to read and debug all of it |
| 2026-10-08 | One verifier does QA and review | Fewer handoffs. Independence comes from fresh context and no edit tools |
| 2026-10-08 | `propose` (no auto-merge) is the default | The system must earn trust with data first |
| 2026-10-08 | Use Claude Code permissions and the sandbox, not guard hooks | A regex hook is not a security boundary |
| 2026-10-08 | Thesis: measure how much you can trust the workflow | Evaluation is the gap in most agent workflows |
| 2026-10-08 | Build the check script and result format first | It is deterministic and ordinary tests can check it |
| 2026-10-08 | Use a GitHub commit status and branch protection for merge safety | GitHub enforces the rule; a local lock is only the fallback |
| 2026-10-08 | Use our own config, labels, result format and defect categories | The project must show original work |
| 2026-10-09 | Name: `trust-factory` | It states the thesis, and almost no other project uses it |
| 2026-10-09 | The repo stays private until Phase 6 | The full history becomes visible when it goes public |

## Open questions

- Which project is the pilot? It needs a fast verify command.
- Do we keep the state in GitHub issue labels (current design) or in plain markdown files?
- How do we install the workflow: as a Claude Code plugin, or as files copied into the target repo?
- How do we deny `git push` for the verifier only? Check the subagent tool and permission options.
- How do we get the token count for each agent run, for the ledger?
- Where do we publish the ledger and the scorecard: in the repo, or only in the README?
- Does the builder use a test-driven development skill when one is installed?
