# Learnings: Flow-Based Orchestration

**PR:** #9
**Branch:** feat/flow-orchestration
**Date:** 2026-03-23

## Orchestrator

### What Went Wrong
- Spike shipped skill content in orchestrator systemMessage, defeating subagent isolation — Codex caught this
- State machine had dead fields (learnings_done, docs_done) never set by any trigger
- doc-reviewer agent shipped without full integration (no orchestrator routing, no subagent-stop-check, no gitignore)
- Sentinel triggers used substring matching — `cat` or `rm` could false-trigger state transitions
- `load_skill_content()` duplicated verbatim in two hooks instead of extracted to preamble
- Multiple failed attempts to probe PostToolUse hooks via settings.json edits (permission issues, jq failures)

### What Went Right
- Worktree isolation made spiking fast and safe
- 4-layer fast-exit design keeps overhead near-zero for 99% of Bash commands
- Codex independent review caught 10 issues including the critical skill-content leak
- SubagentStart injection is architecturally sound — subagent can't bypass its own system prompt

### Unnecessary Human Involvement
- User had to point out doc-reviewer was missing sentinel file write — should have applied same template to all three agents from the start

### Rules to Extract
- When creating multiple similar files, apply the same protocol template to ALL of them before moving on
- Never leak skill content to the parent agent — only inject-skill.sh should provide skill instructions to subagents
- Substring matching on command text is fragile — require write operators alongside filenames for state triggers
- Extract shared functions to preamble immediately — don't ship duplicated helpers across hooks
- SubagentStart + systemMessage injection is strictly more powerful than PostToolUse blocking for workflow enforcement

---

## Review Agent

### Findings Summary
- Codex found 10 issues; 6 accepted as fixes (skill leak, dead states, doc integration, fragile triggers, DRY, jq perf)
- 1 critical gap: .workflow-state corruption has no validation/recovery
- All 6 fixes accepted by user, ready to implement

### What Was Missed
- Should have caught skill-content leak before shipping — the orchestrator's purpose contradicted inject-skill's purpose

### Rules to Extract
- Always run Codex review on new architectural features — cross-model review catches blind spots
- State machines must only track states that have write triggers — dead state fields create confusion

---

## QA Agent

### Findings Summary
- 265 unit + 13 integration tests passing
- 4 test gaps identified from accepted fixes (will be covered during implementation)

### What Was Missed
- No test for orchestrator injecting when review is done but QA isn't (only tested PR create → review)
- No test for partial PR comment nudge (review done, QA posts without sentinel)

### Rules to Extract
- Test every state transition individually, not just the happy path sequence

---

## Post-Merge Extraction

*After merge, extract actionable rules from above into `.right-hooks/rules/learned-patterns.md`.*
*Format: one line per rule, actionable, no context.*
