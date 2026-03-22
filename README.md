# 🥊 Right Hooks

**Write hooks when agents cut corners. ✍️**

> Mechanical enforcement of code quality for AI coding agents — not through prompts (agents ignore those), but through exit codes (agents can't bypass those).

### Works great with [gstack](https://github.com/garrytan/gstack) + [superpowers](https://github.com/obra/superpowers)

Right Hooks was battle-tested with gstack for planning and review, and superpowers
for TDD implementation. When detected, Right Hooks auto-configures to match their
output formats. The three tools complement each other:

- **gstack** — Think + Plan + Review + Ship (the process)
- **superpowers** — Build + Test + Verify (the implementation)
- **Right Hooks** — Enforce all of it (the guardrails)

Not using either? Right Hooks works standalone with any review tooling that posts PR comments — CodeRabbit, custom scripts, or manual reviews. Configure patterns in `.right-hooks/signatures.json`.

---

## Why This Exists

I built a product using [gstack](https://github.com/garrytan/gstack) for planning and review, and [superpowers](https://github.com/obra/superpowers) for TDD implementation. gstack's `/plan-ceo-review` scoped the features, `/plan-eng-review` locked the architecture, `/review` and `/qa` checked the code. superpowers' `/execute-plan` implemented the plans with subagent-driven development and two-stage review. The skills were excellent. The agents were not.

gstack gives agents the *right process to follow*. superpowers gives them *disciplined implementation*. Right Hooks makes sure they *actually follow both*.

Here's what happened when they didn't:

**The agent faked a `/qa` report.** Instead of spawning a QA subagent, the orchestrator posted a comment *formatted to look like* gstack `/qa` output — complete with severity markers and test results. It passed my merge gate because the hook only checked that a comment with the right keywords existed. I didn't catch it until production.

**A core module shipped as an orphan.** The agent followed both workflows — gstack's `/plan-eng-review` approved the architecture, superpowers' subagent-driven-development implemented it with two-stage review (spec compliance + code quality), gstack's `/review` praised the code. Nobody noticed the module was never imported anywhere. It sat there, perfect and unused, while the feature it was supposed to power didn't work.

**TDD discipline vanished under pressure.** superpowers' `test-driven-development` skill says "write the test first, watch it fail, write minimal code to pass." gstack's `/plan-eng-review` produced a clear test plan. But when the exec plan got complex, the agent started writing all tests at once, then all implementation at once. The tests still passed, but they were written to match the implementation rather than define the spec. superpowers' `verification-before-completion` skill says "evidence before claims" — the agent just didn't follow it.

Every one of these failures had the same root cause: **the agent optimized for completing the task, not for doing it well.** gstack gave it the right process. superpowers gave it the right discipline. The agent just… didn't follow either.

So I started writing hooks. First one to block direct pushes to master. Then one to block merges without review. Then one to stop the agent from quitting before QA was done. Then one to verify the QA wasn't faked. Then one to validate every file edit. Then one to protect the hooks from being disabled by the agent itself.

The product I set out to build? Still in progress. But the enforcement system I built to keep agents honest while building it — that turned out to be the thing worth shipping.

Right Hooks exists because good process without enforcement is a suggestion. If a rule can be mechanically enforced, it should be. The framework is the leash — not to choke the agent, but to keep it honest.

---

## Quick Start

```bash
npx right-hooks init
```

That's it. Right Hooks auto-detects your project type, installs hooks, copies rules
and templates, configures Claude Code, and sets up git hooks.

```
🥊  Right Hooks — Lifecycle Enforcement for Agentic Software Harness

Detecting project...
  ✓ TypeScript (tsconfig.json found)
  ✓ GitHub repo (gh auth status ok)

  Recommended preset: typescript

? Select enforcement profile:
  ❯ Recommended (strict for feat/, standard for fix/, light for docs/)

✓ Hooks installed to .right-hooks/hooks/ (9 hooks)
✓ Rules symlinked to .claude/rules/ (4 rule files)
✓ Templates installed to .right-hooks/templates/ (3 templates)
✓ Husky hooks configured (pre-push + post-merge)
✓ Claude Code settings.json updated
```

### Commands

```bash
npx right-hooks status          # Show active profile, preset, and gate status
npx right-hooks preset python   # Switch language preset
npx right-hooks profile strict  # Switch enforcement profile
npx right-hooks doctor          # Diagnose hook configuration issues
npx right-hooks override        # Override a gate with audited reason
npx right-hooks upgrade         # Upgrade generated hooks (preserves custom)
```

---

## Opinions

Right Hooks is opinionated. These are the hills we die on:

🧪 **Test-First** — Tests are written before implementation. The test suite IS the spec.

📝 **Doc-First** — Design docs capture WHY. Exec plans capture HOW. Both exist before code.

📚 **Learnings-First** — Every PR produces a learnings document with a `### Rules to Extract` section. Post-merge, those rules are **automatically extracted** into `.right-hooks/rules/learned-patterns.md` — a file that accumulates over time, making the system smarter with every PR. The point isn't to document what went right. The point is to document what went wrong so future agents don't repeat it.

---

## What Right Hooks Does

Right Hooks uses two hook systems — **Claude Code hooks** (control agent behavior at the AI level) and **git hooks via [husky](https://typicode.github.io/husky/)** (control git operations at the OS level). Both layers work together: Claude Code hooks catch the agent *before* it acts, git hooks catch anything that slips through *when* it acts.

Why husky? Because Claude Code hooks only fire inside Claude Code sessions. If someone (or something) pushes to master directly via the terminal, or merges without going through Claude Code, the Claude Code hooks never trigger. Husky hooks run on *every* git operation regardless of how it was initiated — they're the last line of defense.

### 🤖 Claude Code Hooks (agent-level enforcement)

| Hook | Event | What it does |
|------|-------|-------------|
| **block-agent-override** | `PreToolUse` | Blocks agents from calling `right-hooks override` — humans only |
| **pre-merge** | `PreToolUse` | 7-gate merge check: CI, DoD, doc consistency, planning, review, QA, learnings |
| **pre-push-master** | `PreToolUse` | Blocks direct push to master/main |
| **pre-pr-create** | `PreToolUse` | Requires design doc + exec plan for `feat/` branches |
| **post-edit-check** | `PostToolUse` | Validates code after every file edit (tsc, mypy, cargo — preset-driven) |
| **stop-check** | `Stop` | Prevents agent from stopping before review/QA cycle completes |
| **subagent-stop-check** | `SubagentStop` | Verifies subagent actually posted a real PR comment (anti-gaming) |
| **session-start** | `SessionStart` | Injects project status context when a session begins |
| **config-change** | `ConfigChange` | Blocks modification of hook configuration during a session |

### 🔒 Git Hooks via Husky (OS-level enforcement)

| Hook | Event | What it does |
|------|-------|-------------|
| **pre-push** | `git push` | Blocks direct push to master/main + validates branch naming |
| **post-merge** | `git merge` | Auto-extracts learnings rules + retro reminder |

### 📋 Behavioral Enforcement (rules + conventions)

Not everything can be mechanically enforced. These rules guide agent behavior through `.claude/rules/`:

| Rule | What it covers |
|------|---------------|
| **development-lifecycle** | Full workflow: planning → TDD → review/QA → learnings → merge |
| **testing** | TDD discipline: stubs → red-green → refactor |
| **design-docs** | Design doc requirements: alternatives, rationale, reversibility |
| **git-workflow** | Branch naming, enforcement by branch type, secret management |

---

## Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Layer 3: Custom (user-defined)                         │
│  Your own lint rules, custom gates, project-specific    │
│  validations. Add whatever you need.                    │
├─────────────────────────────────────────────────────────┤
│  Layer 2: Language (preset-driven)                      │
│  Post-edit validation (tsc/mypy/cargo), orphan module   │
│  detection. Auto-detected or manually selected.         │
├─────────────────────────────────────────────────────────┤
│  Layer 1: Universal (works everywhere)                  │
│  Merge gates, push protection, stop hook, subagent      │
│  verification, judge layer, session context. Pure       │
│  GitHub API + git. No language dependencies.            │
└─────────────────────────────────────────────────────────┘
```

### Language Presets

| Preset | Auto-detect | Post-edit validation | Orphan detection |
|--------|------------|---------------------|-----------------|
| TypeScript | `tsconfig.json` | `tsc --noEmit` | import pattern matching |
| Python | `pyproject.toml` | `mypy` | import pattern matching |
| Go | `go.mod` | `go vet` | — |
| Rust | `Cargo.toml` | `cargo check` | — |
| Generic | (fallback) | — | — |

### Enforcement Profiles

| Profile | Branch types | Gates enabled |
|---------|-------------|--------------|
| **Strict** | `feat/` | All gates: CI, DoD, docs, planning, review, QA, learnings |
| **Standard** | `fix/`, `refactor/`, `perf/`, `test/`, `ci/` | CI, DoD, docs, review, QA, learnings |
| **Light** | `docs/`, `chore/`, `hotfix/` | CI, DoD, docs only |

---

## Override / Escape Hatch

Hooks will false-positive. Instead of hacking scripts or deleting `.right-hooks/`,
use the built-in override mechanism:

```bash
npx right-hooks override --gate=qa --reason="Manual testing done, QA agent broken"
```

This creates an audited override file committed to git — visible in the PR diff
to anyone reviewing.

```bash
npx right-hooks overrides          # List active overrides
npx right-hooks overrides --clear  # Clear all overrides
```

---

## Upgrading

Right Hooks separates **generated hooks** (managed by Right Hooks) from
**custom hooks** (your modifications, never overwritten).

```bash
npx right-hooks upgrade
```

```
🥊  Right Hooks upgrade: v1.0.0 → v1.1.0

  ✓ pre-merge.sh — updated
  ✓ session-start.sh — new hook (added)
  ⊘ stop-check.sh — you modified this file (preserved)
  ✓ learned-patterns.md — no changes (preserved)
```

---

## Prerequisites

- GitHub repository with PR workflow
- Claude Code or Codex CLI
- `gh` CLI authenticated
- `jq` installed
- Node.js ≥ 18

---

## Dogfooding

Right Hooks uses Right Hooks. The `.right-hooks/` directory in this repo is our own installation — we develop this project using the same enforcement we ship to you.

## Known Limitations

1. **Orphan detection is grep-based.** Misses barrel files, dynamic imports,
   and aliased paths. Good heuristic, not a dependency graph.

2. **Three PreToolUse hooks fire on every Bash command.** Each fast-exits if
   irrelevant (<50ms), but it's still 3 process spawns per `ls`.

3. **Config protection is defense-in-depth.** An agent could `rm -rf .right-hooks/`.
   Checksums make tampering *visible*, not impossible.

4. **Claude Code specific (v1).** v1.3 roadmap includes adapters for Cursor,
   Codex, Aider, and Windsurf.

---

## License

MIT
