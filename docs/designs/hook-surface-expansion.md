# Design: Hook Surface Expansion

## Problem Statement

Right Hooks uses 6 of 25 available Claude Code hook events. The inject-skill.sh
hook reads `.agent_name` from SubagentStart events, but the official schema provides
`.agent_type` and `.agent_id`. Skill injection has been silently broken. Additionally,
agents can schedule their own future runs via CronCreate/RemoteTrigger, and agent
death events (rate limits, auth failures) are invisible.

## Approach

Fix the 3 P0 bugs (inject-skill schema, skills.js field loss, settings-merge keying),
then add 3 new hooks targeting high-value events from the official Claude Code hooks
API: agent-spawn-guard (PreToolUse Agent), stop-failure-logger (StopFailure), and
block-scheduling (PreToolUse CronCreate/RemoteTrigger).

## Key Decisions

- **Agent type allowlist in skills.json** — `agentTypes` array per gate, resolved by
  shared `rh_resolve_gate_for_agent_type` helper with legacy fallback
- **agent-spawn-guard is a guard, not a gate** — allows unknown types (log only),
  blocks dangerous prompt patterns (exit 2)
- **Settings merge keys on matcher+command** — not just command, to handle same
  hook under different matchers
- **Dropped gate-task-tracker and session-cleanup** per Codex outside voice review —
  .workflow-state is guidance not enforcement, no session dimension

## Review History

- CEO review (HOLD SCOPE): 0 critical gaps, Codex outside voice ran (10 findings, 5 accepted)
- Eng review (FULL): 2 issues found (settings-merge keying, DRY helper), both resolved
