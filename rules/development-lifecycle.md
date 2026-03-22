# Development Lifecycle

This project follows a doc-first, test-first workflow enforced by Right Hooks
and agent instruction rules.

## Workflow

Right Hooks enforces the lifecycle. Which tools you use at each phase is up to you.

```
THINK → PLAN → BUILD → REVIEW → SHIP → REFLECT
```

### Phase Guide

Pick the tools that fit your setup. Mix and match freely.

#### THINK — Define the problem before writing code

| Tool | Command | What it does |
|------|---------|-------------|
| gstack | `/office-hours` | 6 forcing questions, reframes your product, outputs design doc |
| superpowers | `/brainstorm` | Collaborative dialogue, explores requirements before implementation |
| Neither | Write `docs/designs/<feature>.md` manually | Template: `.right-hooks/templates/design-doc.md` |

#### PLAN — Lock architecture, edge cases, test plan

| Tool | Command | What it does |
|------|---------|-------------|
| gstack | `/plan-ceo-review` → `/plan-eng-review` | CEO scope review + eng architecture review with ASCII diagrams |
| gstack | `/plan-design-review` | UI/UX review (if frontend scope) |
| superpowers | `/write-plan` | Implementation plan with bite-sized tasks, assumes zero codebase knowledge |
| Neither | Write `docs/exec-plans/<feature>.md` manually | Template: `.right-hooks/templates/exec-plan.md` |

**Plan storage:** gstack stores plans in `~/.gstack/projects/`. superpowers stores
plans in `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`. Right Hooks' `pre-pr-create`
hook accepts plans from any of these locations.

🔒 **ENFORCEMENT:** `pre-pr-create` hook blocks PR on `feat/` branches without
a design doc + exec plan + Definition of Done.

#### BUILD — Implement with TDD discipline

| Tool | Command | What it does |
|------|---------|-------------|
| superpowers | `/execute-plan` | Sequential TDD execution with review checkpoints |
| superpowers | `subagent-driven-development` | Parallel: fresh subagent per task + 2-stage review (spec then quality) |
| Neither | Strict TDD: stubs → red-green → refactor | See `testing.md` for process |

**Defense in depth:** superpowers' `verification-before-completion` skill behaviorally
enforces "evidence before claims." Right Hooks' `post-edit-check` hook mechanically
enforces validation after every file edit. Both layers work together.

🔒 **ENFORCEMENT:** `post-edit-check` hook runs type checker after every file edit.
Orphan module detection warns on new files with no consumers.

#### REVIEW — Verify code quality and correctness

| Tool | Command | What it does |
|------|---------|-------------|
| gstack | `/review` | Structural code audit, auto-fixes where possible |
| gstack | `/qa <url>` | Opens real browser, clicks through flows |
| gstack | `/design-review` | Visual QA on live preview |
| superpowers | `requesting-code-review` | Dispatches code-reviewer subagent with crafted context |
| Neither | Spawn review + QA subagents manually, or use CodeRabbit / manual review |

🔒 **ENFORCEMENT:** `stop-check` hook blocks agent from stopping before review
and QA comments exist on the PR. `subagent-stop-check` verifies comments are real
(sentinel file protocol). `judge` hook filters low-quality review comments.

#### SHIP — Merge and deploy

| Tool | Command | What it does |
|------|---------|-------------|
| gstack | `/document-release` → `/ship` | Doc consistency check + test run + PR creation |
| superpowers | `finishing-a-development-branch` | 4 options: merge locally, create PR, keep branch, discard |
| Neither | `gh pr create` → human reviews → `gh pr merge` |

**Before merge, write learnings:** `docs/retros/<feature>-learnings.md`
(template: `.right-hooks/templates/learnings.md`). Each agent section must include
a `### Rules to Extract` with actionable one-line rules.

🔒 **ENFORCEMENT:** `pre-merge` hook runs 7-gate check:
1. CI green
2. DoD complete (no unchecked items in PR body)
3. Doc consistency
4. Planning artifacts (feat/ branches)
5. Code review comment with severity findings
6. QA comment with test results
7. Learnings doc with agent sections + Rules to Extract

#### REFLECT — Learn and improve

| Tool | Command | What it does |
|------|---------|-------------|
| gstack | `/retro` | Weekly engineering retrospective with metrics and trends |
| Neither | Review learnings, update documentation |

**Post-merge automation:** husky `post-merge` hook automatically extracts
`### Rules to Extract` from the latest learnings file and appends them to
`.right-hooks/rules/learned-patterns.md`. Deduplicates automatically.
This is mechanical — no agent involvement needed.

🔒 **ENFORCEMENT:** husky `post-merge` hook handles extraction. `pre-merge`
hook verifies Rules to Extract section exists before allowing merge.

---

## Common Setups

### gstack + superpowers (recommended — most coverage)
```
THINK    → gstack /office-hours
PLAN     → gstack /plan-ceo-review → /plan-eng-review
BUILD    → superpowers /execute-plan or subagent-driven-development
REVIEW   → gstack /review → /qa
SHIP     → gstack /document-release → /ship
REFLECT  → gstack /retro
```

### gstack only
```
THINK    → gstack /office-hours
PLAN     → gstack /plan-ceo-review → /plan-eng-review
BUILD    → Manual TDD (see testing.md)
REVIEW   → gstack /review → /qa
SHIP     → gstack /ship
REFLECT  → gstack /retro
```

### superpowers only
```
THINK    → superpowers /brainstorm
PLAN     → superpowers /write-plan
BUILD    → superpowers /execute-plan or subagent-driven-development
REVIEW   → superpowers requesting-code-review
SHIP     → superpowers finishing-a-development-branch
REFLECT  → Manual retrospective
```

### Standalone (no external tools)
```
THINK    → Write design doc manually
PLAN     → Write exec plan manually
BUILD    → TDD: stubs → red-green → refactor
REVIEW   → Spawn subagents or use CodeRabbit / manual review
SHIP     → gh pr create → gh pr merge
REFLECT  → Review learnings
```

Right Hooks enforcement works identically in all setups. The hooks don't care
which tool produced the review comment — only that it matches the configured
content signatures.

---

## Principles

- **Doc-first:** Design docs and execution plans precede code. The design doc
  captures WHY; the execution plan captures HOW. Both are committed before
  implementation begins.
- **Test-first:** Tests are written before implementation. No PR without test
  coverage. See testing.md for the full TDD process.
- **Learnings-first:** Every PR produces a learnings doc. Rules are extracted
  and accumulated automatically. The system gets smarter with every merge.
- **Completeness is cheap:** AI compresses implementation time 10-100x. Don't
  skip the last 10% to "save time" — with AI, that 10% costs seconds.

## Definition of Done

Every execution plan MUST include a Definition of Done — a concrete, checkable
list that must ALL be true before the work is complete.

**Required items:**
1. All CI checks green (use `gh run list` to monitor autonomously)
2. No manual human steps remaining
3. Verification checklist complete
4. No stale data or side effects
5. DoD carried to PR description as checklist
6. Re-verify after every commit
7. Learnings committed before merge (with Rules to Extract)

**Anti-patterns:**
- Declaring done when CI is red
- Asking the human to check build logs you could read via `gh run view`
- Moving to review or merge while any check is failing
- Suggesting merge before review is complete
- Faking agent comments to bypass staleness checks
- Calling `right-hooks override` (humans only)

## Enforcement

Right Hooks mechanically enforce this workflow:
- `block-agent-override.sh` — blocks agents from self-approving gate bypasses
- `pre-pr-create.sh` — blocks PR without planning artifacts on feat/ branches
- `pre-merge.sh` — blocks merge without CI, review, QA, learnings
- `stop-check.sh` — blocks agent from stopping before review/QA cycle
- `subagent-stop-check.sh` — verifies subagent produced real artifacts
- `post-edit-check.sh` — validates code after every edit
- `judge.sh` — filters low-quality review comments
- `session-start.sh` — injects project context at session start
