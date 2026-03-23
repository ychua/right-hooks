# Design Doc: Flow-Based Orchestration

**Status:** APPROVED
**Author:** rhua
**Date:** 2026-03-23

## Problem Statement

Right Hooks' current enforcement is gate-based: hooks block at boundaries (stop,
merge, PR create) when workflow steps are missing. This creates two problems:

1. **Reactive, not proactive.** The agent works freely, tries to stop, gets blocked,
   then must figure out what to do. This creates friction and wasted cycles.

2. **Fakeable enforcement.** All three enforcement levels (sentinel, signature,
   provenance) can be bypassed by the orchestrating agent writing files directly
   without ever invoking the configured skill. There's no way to prove `/review`
   was actually called vs the agent doing the review inline.

## Alternatives Considered

### Option A: Pre-baked agent files
- **Description:** Ship `.claude/agents/qa-reviewer.md` with gstack's SKILL.md
  content hardcoded as the system prompt.
- **Pros:** Simple, no hook needed, subagent gets exact instructions.
- **Cons:** Hardcodes a specific skill provider. Stale if gstack updates its skill.
  Users must manually update agent files when switching providers.
- **Effort:** Small

### Option B: SubagentStart hook with dynamic injection
- **Description:** Ship generic agent definitions. A SubagentStart hook detects the
  agent name, reads `skills.json` for the configured provider, finds the installed
  SKILL.md, and injects it as a systemMessage.
- **Pros:** Provider-agnostic. Always uses the latest installed skill. Same detection
  logic Right Hooks already uses for signatures. Works with any skill provider.
- **Cons:** Depends on SubagentStart hook support in Claude Code. Slightly more moving
  parts than Option A.
- **Effort:** Medium

### Option C: PostToolUse orchestrator only (no subagent enforcement)
- **Description:** A PostToolUse hook that injects next-step instructions after
  significant Bash commands (gh pr create, sentinel writes). Proactive guidance
  but no enforcement improvement.
- **Pros:** Improves UX — agent never gets lost. Complements existing gates.
- **Cons:** Doesn't solve the enforcement gap. Agent still does everything inline.
- **Effort:** Small

## Decision

**Chosen:** Option B + Option C (both layers)

**Why:** Option B solves the enforcement gap — the subagent's system prompt IS the
skill, so it can't skip it. Option C improves UX by proactively guiding the
orchestrating agent through the workflow. Together they form a complete system:
flow orchestration (proactive) + gates (safety net) + skill injection (enforcement).

**What we lose:** Option A's simplicity. But the added complexity is minimal (one
hook + skills.json lookup, which we already have).

**Reversibility:** Two-way door. Both hooks are additive — removing them reverts
to gate-only enforcement without breaking anything.

**Upgrade path:** If Claude Code adds native Skill tool tracking, the SubagentStart
hook becomes unnecessary. The agent definitions and orchestrator would remain useful.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ENFORCEMENT CHAIN                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Agent runs gh pr create                                    │
│    │                                                        │
│    ▼                                                        │
│  PostToolUse: workflow-orchestrator.sh                       │
│    → systemMessage: "Next step: code review.                │
│       Spawn the 'reviewer' agent."                          │
│    │                                                        │
│    ▼                                                        │
│  Agent spawns 'reviewer' subagent                           │
│    │                                                        │
│    ▼                                                        │
│  SubagentStart: inject-skill.sh                             │
│    → reads skills.json → finds gstack /review               │
│    → reads ~/.claude/skills/gstack/review/SKILL.md          │
│    → systemMessage: "<full skill content>"                  │
│    │                                                        │
│    ▼                                                        │
│  Subagent runs REAL gstack review workflow                   │
│    → posts PR comment                                       │
│    → writes .review-comment-id (sentinel)                   │
│    → writes .skill-proof-codeReview (provenance)            │
│    │                                                        │
│    ▼                                                        │
│  Agent tries to stop                                        │
│    │                                                        │
│    ▼                                                        │
│  Stop hook: stop-check.sh (safety net)                      │
│    → verifies sentinel + signature + provenance             │
│    → PASS (everything done by real subagent)                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Scope

### In Scope
- [x] PostToolUse workflow orchestrator (proactive guidance)
- [x] SubagentStart inject-skill hook (enforcement via architecture)
- [x] Generic agent definitions (reviewer, qa-reviewer, doc-reviewer)
- [x] Updated stop-check/pre-merge messaging to reference agents
- [x] Unit tests for both hooks

### Out of Scope
- init.js changes (copying agents, adding hook to settings.json) — follow-up
- doctor.js validation of agent files — follow-up
- Integration tests for full enforcement chain — requires live Claude Code

## Open Questions

- [x] Does SubagentStart fire reliably? — Spiked and tested via unit tests
- [ ] What JSON schema does Claude Code provide to SubagentStart hooks?
  Currently assuming `{"agent_name": "..."}` — needs verification
