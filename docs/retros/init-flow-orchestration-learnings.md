# Learnings: Init Integration for Flow Orchestration

**PR:** #11
**Branch:** feat/init-flow-orchestration
**Date:** 2026-03-23

## Orchestrator

### What Went Wrong
- Nothing significant — this was straightforward wiring work following existing patterns

### What Went Right
- All four files (settings.json, init.js, doctor.js, upgrade.js) followed the same patterns already established for other hooks — no new abstractions needed
- README 🔜 markers provided a clear checklist of what needed shipping
- The TODO from PR #10's eng review mapped directly to the implementation

### Unnecessary Human Involvement
- None — fully autonomous implementation

### Rules to Extract
- When deferring init.js integration, always create a TODO with the exact files that need updating (settings.json, init.js, doctor.js, upgrade.js)
- Mark unshipped features in README with 🔜 so the gap is visible and trackable
- Agent definitions should always be overwritten on upgrade (they're generated, not user-customized)

---

## Review Agent

### Findings Summary
- 3 MEDIUM issues found and fixed (awk field separator, grep column matching, mock column order)
- 0 CRITICAL, 0 HIGH

### Rules to Extract
- Always use `awk -F'\t'` for tab-delimited CLI output — default field splitting breaks multi-word names
- Check `gh api` exit code independently of downstream jq — pipeline masks API failures

---

## QA Agent

### Findings Summary
- 279 tests passing (265 unit + 14 integration)
- Doctor validates all 12 hooks
- New test: API failure gracefully skips comment gates

### Rules to Extract
- Test API failure paths explicitly — mock both success and failure to verify graceful degradation

---

## Post-Merge Extraction

*After merge, extract actionable rules from above into `.right-hooks/rules/learned-patterns.md`.*
*Format: one line per rule, actionable, no context.*
