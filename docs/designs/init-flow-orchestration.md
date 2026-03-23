# Design Doc: Init Integration for Flow Orchestration

**Status:** APPROVED
**Author:** rhua
**Date:** 2026-03-23

## Problem Statement

PR #9 shipped workflow-orchestrator.sh, inject-skill.sh, and agent definitions
but deferred wiring them into init.js. Users must manually set up these hooks.
The README marks them 🔜, which is confusing for new users.

## Alternatives Considered

### Option A: Wire into existing init.js (chosen)
- **Description:** Add hook registrations to settings.json template, agent copying to init.js, hook validation to doctor.js
- **Pros:** Minimal change, follows existing patterns exactly
- **Cons:** None — this is pure completion of deferred work
- **Effort:** S (~15min)

### Option B: Separate installer script
- **Description:** Create a standalone `npx right-hooks install-orchestration` command
- **Pros:** Can be run independently without full init
- **Cons:** Unnecessary indirection, splits what should be one init flow
- **Effort:** M (~30min)

## Decision

**Chosen:** Option A — wire into existing init.js

**Why:** This is deferred work from PR #9, not a new feature. The patterns already exist (hook registration, agent copying, doctor validation). Just filling in the gaps.

**Reversibility:** Two-way door. Removing the entries from settings.json and doctor.js reverts to the pre-PR #9 state.

## Scope

### In Scope
- [x] settings.json: PostToolUse/Bash for orchestrator, SubagentStart for inject-skill
- [x] init.js: copy agents/*.md to .claude/agents/
- [x] doctor.js: add both hooks to expectedHooks
- [x] upgrade.js: update agent definitions
- [x] README: remove 🔜 markers
- [x] TODOS.md: mark Phase 2.5 complete

### Out of Scope
- Verifying Claude Code's actual SubagentStart JSON schema — will verify in production
