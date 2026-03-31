# Learnings: Hook Surface Expansion

**PR:** #19
**Branch:** feat/hook-surface-expansion
**Date:** 2026-04-01

## Orchestrator

### What Went Wrong
- Initial proposal mixed verified facts with unverified speculation about Claude Code internals. Reframing around the official API docs at code.claude.com/docs/en/hooks was the turning point.
- The plan originally included gate-task-tracker.sh and session-cleanup.sh. Both were dropped after Codex outside voice correctly identified that .workflow-state is guidance (not enforcement) and has no session dimension. Should have traced the enforcement boundary (stop-check reads PR comments, not .workflow-state) before proposing to extend it.
- Commit message containing "right-hooks override" triggered block-agent-override hook. Had to rephrase. Agent commit messages should avoid trigger phrases.

### What Went Right
- Fetching the official Claude Code hooks documentation (WebFetch on code.claude.com/docs/en/hooks) gave us the exact JSON schema for all 25 events. This turned speculation into facts and revealed the inject-skill schema bug was worse than assumed (field was never correct).
- CEO review with Codex outside voice was high-value. Codex found the skills.js field preservation bug (line 89) that the human review missed. Cross-model review catches different classes of issues.
- The rh_resolve_gate_for_agent_type helper with legacy fallback made the upgrade path non-breaking. Old skills.json without agentTypes still works via the case-statement fallback.

### Unnecessary Human Involvement
- None. The review was interactive by design (CEO + Eng review modes). The human made 8 decisions during review, all of which shaped the final scope. No unnecessary escalations.

### Rules to Extract
- Always fetch official API docs before building on assumed schemas — use WebFetch on the vendor's documentation URL
- When extending a state file (.workflow-state), trace who reads it first — if enforcement hooks don't read it, it's guidance only
- Include a legacy fallback when changing config schemas (agentTypes) so upgrades are non-breaking
- Agent commit messages must not contain hook trigger phrases like "right-hooks override"
- Cross-model review (Codex outside voice) catches field-level bugs that single-model review misses
- The PreToolUse event with tool-specific matchers (Agent, CronCreate) is a stronger enforcement point than tool-specific events (SubagentStart) because PreToolUse can block (exit 2)

---

## Review Agent

### Findings Summary
- CEO review reframed the proposal from 8 speculative items to 6 verified items based on official API
- Codex outside voice found 10 issues, 5 accepted: skills.js field loss, workflow-state misuse, session-cleanup cross-session risk, agent-spawn-gate naming honesty, stats.js missing consumer
- Eng review found 2 issues: settings-merge keying bug, DRY violation (shared preamble helper)

### What Was Missed
- The inject-skill schema bug was a Known Limitation (#2) in README but nobody had verified it against real docs. Should have verified when the limitation was first documented.
- The .claude/settings.json sync issue (missing SubagentStart) was not a code bug but a "never ran upgrade" issue. The existing settings-merge.js was correct. Time was spent analyzing a non-bug.

### Rules to Extract
- Verify Known Limitations against official documentation periodically — they may be fixable
- When a "bug" is reported in installed config, check if `npx right-hooks upgrade` resolves it before debugging the merge logic
- Rename hooks honestly — "guard" (allows by default, blocks patterns) vs "gate" (blocks by default, allows known)

---

## QA Agent

### Findings Summary
- 391 tests all green (374 unit + 17 integration)
- 19 new tests added, 25 existing tests updated for schema change
- Coverage: 22/22 new code paths tested (100%)

### What Was Missed
- No integration test for the full agent-spawn-guard + inject-skill sequence (PreToolUse Agent fires, then SubagentStart fires). Individual hooks are tested but the interaction is not. Low risk since they're independent hooks, but a lifecycle test would increase confidence.

### Rules to Extract
- When changing JSON field names in hooks, update ALL test fixtures in the same commit — the tests should fail RED immediately after the schema change
- New hooks need tests for both the allow path (exit 0) and block path (exit 2) at minimum

---

## Post-Merge Extraction

*After merge, extract actionable rules from above into `.right-hooks/rules/learned-patterns.md`.*
*Format: one line per rule, actionable, no context.*
