# Learnings: Configurable Skill Dispatch

**PR:** #7
**Branch:** feat/configurable-skills
**Date:** 2026-03-23

## Orchestrator

### What Went Wrong
- Codex review caught 4 HIGH issues that the CEO review missed: runtime provider check, backward compat regression, redundant gate namespace, provider field drift
- Design doc needed 3 rounds of adversarial spec review (4/10 → 6/10 → 7/10) before being implementation-ready
- Test helper `setup_skills_repo` used command substitution `$()` which lost the `cd` — functions returning values via `echo` inside `$()` run in a subshell

### What Went Right
- Codex independent review was high-value — the 4-tier fallback design came directly from Codex finding #3
- Using profile gate names (`codeReview` instead of `review`) eliminated a whole translation layer
- The `rh_skill_command` helper with cached JSON read matches existing preamble patterns perfectly

### Unnecessary Human Involvement
- None — all issues self-diagnosed via test failures and Codex review

### Rules to Extract
- Always run Codex independent review for architectural changes — it catches different classes of issues than Claude
- When replacing hardcoded behavior with config, always include a fallback that preserves the exact current behavior for existing installs
- Shell functions that need to both `cd` and return a value should use a global variable (like `REPO`), not `echo` inside `$()`
- Use `HOME="$tmpdir"` in tests to isolate from the developer's real tool installations

---

## Review Agent

### Findings Summary
- Spec review caught schema gaps, missing migration story, and jq injection risk
- Codex caught the backward-compat regression that would have removed tool-specific guidance for existing users

### What Was Missed
- The `$()` subshell issue in test helpers — a bash footgun that's easy to miss

### Rules to Extract
- Test helpers that `cd` must not be called inside `$()` — the `cd` is lost in the subshell

---

## QA Agent

### Findings Summary
- 17 new tests cover all 4 fallback tiers, CLI operations, and edge cases
- `HOME` override pattern needed for provider detection isolation in tests

### What Was Missed
- No integration test for the full lifecycle with skills.json (hook suggests skill → agent runs → sentinel written → hook passes)

### Rules to Extract
- Always override HOME in tests that check provider availability — the developer's real installations leak through
