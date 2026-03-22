# Learnings: 3-Level Skill Enforcement

**PR:** #8
**Branch:** feat/skill-enforcement
**Date:** 2026-03-23

## Orchestrator

### What Went Wrong
- Initial configurable skills PR (#7) only suggested skills — didn't enforce them
- User caught that /document-release was not actually invoked despite being configured
- Integration tests needed provenance files + skill signatures in mock comments

### What Went Right
- 3-level enforcement (behavioral + signature + provenance) is defense in depth
- Null-skill bypass means prompt-based users are unaffected
- Existing sentinel protocol extended cleanly — provenance is the same pattern

### Rules to Extract
- Configurable skills must be enforced, not just suggested — suggestion without enforcement is a comment
- Defense in depth: sentinel (proves comment) + signature (proves content) + provenance (proves process)
- Mock gh must return .body for sentinel lookups when hooks need to verify comment content

---

## Review Agent

### Findings Summary
- Clean implementation, 0 critical issues
- Shared cache `_RH_SKILLS_JSON` works correctly across all three helpers

### Rules to Extract
- When changing what a hook extracts from the API (e.g., .id → .body), update the mock too

---

## QA Agent

### Findings Summary
- 179 tests pass (166 unit + 13 integration)
- Enforcement tested through integration tests (provenance + signature in mocks)

### Rules to Extract
- Add dedicated unit tests for new enforcement helpers (signature match, provenance check) — not just integration coverage
