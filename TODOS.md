# TODOS

Deferred work from the Phase 1 CEO + Eng review (2026-03-22).
See `docs/designs/right-hooks-v1-review.md` for full context.

## Phase 2 — CLI Power-Ups ✅

**Completed:** PR #6 (2026-03-22)

- ~~`npx right-hooks scaffold`~~ — creates docs directories with .gitkeep, runs during init
- ~~`npx right-hooks doctor --fix`~~ — auto-repairs missing hooks, permissions, checksums
- ~~`npx right-hooks diff`~~ — preview what upgrade would change

## Phase 3 — Stats & Observability

### `npx right-hooks stats`
**What:** Gate effectiveness metrics — how often each gate blocks, which are overridden most, learnings extraction rate.
**Why:** Turns Right Hooks from binary enforcement into a feedback loop.
**Effort:** M (human: ~3d / CC: ~30min) | **Priority:** P2
**Depends on:** Needs data model design first. Currently hooks only emit stderr and write override files — no event logging. Needs: event schema, storage location (.right-hooks/.stats/), retention policy, aggregation.

## Phase 4 — Multi-Runtime

### VCS abstraction layer
**What:** Abstract `gh` CLI calls behind a stable data contract so hooks don't depend on GitHub API shapes. Preamble helpers like `rh_fetch_comments()`, `rh_check_ci()` with normalized return shapes.
**Why:** Foundation for GitLab/Bitbucket support. Currently every hook shells out to `gh` directly.
**Effort:** M (human: ~3d / CC: ~30min) | **Priority:** P2
**Depends on:** Should be validated against a second VCS backend (don't build abstraction without second implementation — per Codex review)

### Multi-runtime adapter system
**What:** Adapter layer that translates each runtime's hook format to/from HOOK-CONTRACT v1. Claude Code adapter (refactor existing), then Codex CLI, Cursor, Aider, Windsurf.
**Why:** 5x addressable market. HOOK-CONTRACT.md already defines the portable contract.
**Effort:** L (human: ~2w / CC: ~2-3h) | **Priority:** P1
**Depends on:** VCS abstraction. Codex noted: current hooks assume Claude-specific lifecycle events, env vars, settings format. Each runtime needs investigation.

### Codex CLI adapter (first external adapter)
**What:** Codex uses `.agents/` not `.claude/`, different settings format, different trigger mechanism.
**Why:** Most similar to Claude Code — easiest first adapter to validate the architecture.
**Effort:** S (human: ~1d / CC: ~15min) | **Priority:** P1
**Depends on:** Adapter system

## Phase 5 — CI Enforcement

### GitHub Actions reusable workflow
**What:** `.github/actions/right-hooks-check/action.yml` that runs gate checks as GitHub status checks on PRs.
**Why:** Moves enforcement from local-only to CI-level — visible as green/red checks on the PR page.
**Effort:** M (human: ~3d / CC: ~30min) | **Priority:** P2
**Depends on:** Needs separate design doc. Codex flagged: hooks assume local branch state, gh auth. Actions environment is completely different (detached HEAD, GITHUB_TOKEN permissions, fork-PR behavior).

## Deferred (no phase assigned)

- **PR status badges** — shield.io badges for "Right Hooks enforced"
- **Color-coded terminal output** — ANSI colors for pass/fail (not just emoji)
- **`init --from=<repo>`** — Import hooks/config from another project
- **`explain <gate>`** — Explain what a gate does and why it exists
- **GitLab/Bitbucket VCS support** — Depends on VCS abstraction (Phase 4)
