# Learnings: Upgrade Path Fixes

**PR:** #13
**Branch:** fix/upgrade-path
**Date:** 2026-03-23

## Orchestrator

### What Went Wrong
- CEO review revealed that the upgrade path had been broken since Phase 2.5 — workflow-orchestrator and inject-skill hooks existed on disk but were never called because settings.json wasn't updated during upgrade
- The dogfood installation (this repo) had the same gap — demonstrating that even the project authors didn't notice the silent degradation
- Pushing from a git worktree failed because husky pre-push runs `npm test` which resolves paths relative to the worktree, where `lib/bashunit` didn't exist

### What Went Right
- CEO review (/plan-ceo-review) systematically compared README claims against implementation, catching gaps that manual inspection missed
- Extracting shared helpers (settings-merge.js, skills-merge.js) was the right DRY approach — both init and upgrade now use identical merge logic
- The subagent dispatched to the worktree produced clean, well-tested code on the first pass

### Unnecessary Human Involvement
- Had to manually push from the main repo after worktree push failed — the husky hook infrastructure doesn't handle worktree paths correctly

### Rules to Extract
- When adding new hook event registrations to settings.json, always update upgrade.js merge logic — not just init.js
- When adding new fields to skills.json templates, ensure upgrade.js merges them into existing installs — unconditional preservation loses new features
- Doctor should verify completeness of all config files it manages, not just existence
- Test integration tests against the actual default branch name used in `git init` — don't assume `main`

---

## Review Agent

### Findings Summary
- 0 CRITICAL, 0 HIGH, 2 MEDIUM, 3 LOW findings
- Shallow copy in mergeSettings() shares array refs with input — technically violates immutability contract though no runtime impact since callers serialize immediately
- Silent catch blocks in upgrade.js replace malformed user JSON with defaults without warning

### What Was Missed
- The shallow copy issue should have been caught during implementation — spread operator on objects with nested arrays doesn't deep clone

### Rules to Extract
- When implementing immutable helpers, verify deep cloning of nested structures — spread operator only shallow copies
- Silent catch blocks that discard user data should at minimum log a warning

---

## QA Agent

### Findings Summary
- 288 unit tests pass (23 new), 14 integration tests pass
- Manual verification confirmed merge behaviors work correctly
- Pre-existing integration test bug (wrong branch name) fixed as bonus

### What Was Missed
- Doctor doesn't verify skills.json field completeness (only settings.json) — noted as LOW in review, could be a follow-up

### Rules to Extract
- Always run integration tests in the same environment as pre-push hooks to catch path resolution issues early
- When fixing pre-existing test bugs, verify the fix in the exact test runner context (bashunit), not just manual reproduction

---

## Post-Merge Extraction

*After merge, extract actionable rules from above into `.right-hooks/rules/learned-patterns.md`.*
*Format: one line per rule, actionable, no context.*
