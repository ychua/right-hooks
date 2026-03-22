# Learnings: Phase 2 CLI Power-Ups

**PR:** #6
**Branch:** feat/phase2-cli-powerups
**Date:** 2026-03-22

## Orchestrator

### What Went Wrong
- `pre-pr-create.sh` hardcoded `master` as the base branch — silently failed on repos using `main` because `2>/dev/null` swallowed the fatal error from `git diff master...HEAD`
- Didn't realize `feat/` branches require design doc AND exec plan in the branch diff (not just in the repo) until the hook blocked PR creation

### What Went Right
- All three commands implemented cleanly with tests in one pass — no test failures
- Dogfooding the enforcement system caught a real bug (master vs main) that would have affected every user with a `main` branch
- Reusing upgrade.js comparison logic for diff.js avoided duplication

### Unnecessary Human Involvement
- None — all issues were self-diagnosed via hook feedback

### Rules to Extract
- Always use dynamic default branch detection (`git symbolic-ref refs/remotes/origin/HEAD`) instead of hardcoding `master` or `main`
- When `2>/dev/null` is used on git commands, consider that silenced failures may mask real bugs
- `feat/` branches require both design doc and exec plan in the PR diff, not just existing in the repo

---

## Review Agent

### Findings Summary
- Three new files (scaffold.js, diff.js, doctor.js changes) follow existing patterns well
- `doctor --fix` correctly separates diagnosis from repair — same check logic, conditional fix actions

### What Was Missed
- The `master` hardcoding bug existed since the initial commit but wasn't caught until dogfooding on a `main`-based repo

### Rules to Extract
- Test hooks against both `main` and `master` default branches in integration tests

---

## QA Agent

### Findings Summary
- 25 new tests cover all three commands comprehensively
- Idempotency tested for scaffold (safe to run repeatedly)
- Both `--fix` and non-`--fix` paths tested for doctor

### What Was Missed
- No integration test for the `pre-pr-create` default branch detection fix
- Could add a test for `diff` comparing rules (currently only tests hooks)

### Rules to Extract
- Always include a regression test when fixing a bug found during dogfooding
