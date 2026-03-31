# Right Hooks Hook Contract v1

This document specifies the contract that all Right Hooks hooks follow. The contract
is **independent of any specific agent runtime** — while v1 targets Claude Code,
the contract is designed for portability.

## Contract Specification

```
Contract: Right Hooks Hook v1
─────────────────────────
Input:    JSON on stdin (tool context, session context, or event metadata)
Output:   JSON on stdout (optional — decision + reason)
Blocking: exit 2 = block the action, with reason on stderr
Allow:    exit 0 = allow the action (or omit output entirely)
Degrade:  exit 1 = hook error, non-blocking (fail open, log warning)
Stderr:   human-readable reason (shown to agent on block)
```

## Exit Codes

| Code | Meaning | Effect |
|------|---------|--------|
| `0` | Allow | Action proceeds normally |
| `1` | Hook error | Non-blocking degradation (fail open, log warning) |
| `2` | Block | Action is blocked, reason shown on stderr |

**Principle:** A broken hook degrades gracefully (exit 0), never blocks all
work (exit 2). Only intentional, verified failures should block.

## Shared Preamble

Every Right Hooks hook starts with the shared preamble (`_preamble.sh`), which provides:

1. **Dependency check** — verifies `gh`, `jq`, `git` are available
2. **Auth check** — verifies `gh` is authenticated
3. **Integrity check** — validates hook checksum against `.right-hooks/.checksums`
4. **Helper functions** — `rh_branch()`, `rh_pr_number()`, `rh_has_override()`

If any dependency is missing, the hook exits 0 (graceful degradation) rather
than blocking work.

```bash
# Prerequisites check (shared preamble — every hook starts with this):
for cmd in gh jq git; do
  command -v "$cmd" >/dev/null || { echo "Right Hooks: $cmd not found" >&2; exit 0; }
done
gh auth status >/dev/null 2>&1 || { echo "Right Hooks: gh not authenticated" >&2; exit 0; }
```

## Hook Types

### PreToolUse Hooks
- **Trigger:** Before a tool call (Bash, Write, Edit, etc.)
- **Input:** JSON with `tool_input` containing the command/file being acted on
- **Can block:** Yes (exit 2 prevents the tool call)

### PostToolUse Hooks
- **Trigger:** After a tool call completes
- **Input:** JSON with `tool_result` containing the outcome
- **Can block:** Yes (exit 2 shows error to agent, may prompt retry)

### Stop Hooks
- **Trigger:** When the agent attempts to end its session
- **Input:** JSON with session context
- **Can block:** Yes (exit 2 prevents the agent from stopping)

### SubagentStart Hooks
- **Trigger:** When a subagent is spawned
- **Input:** JSON with `agent_type` and `agent_id`
- **Can block:** No (informational — use for skill injection)

### SubagentStop Hooks
- **Trigger:** When a subagent finishes
- **Input:** JSON with subagent output, `agent_type`, `agent_id`, `last_assistant_message`
- **Can block:** Yes (exit 2 prevents subagent completion acknowledgment)

### StopFailure Hooks
- **Trigger:** When a session ends due to API error (rate limit, auth failure, etc.)
- **Input:** JSON with `error` type and `error_details`
- **Can block:** No (informational — use for observability)

### SessionStart Hooks
- **Trigger:** When a new agent session begins
- **Input:** Empty or session metadata
- **Output:** JSON with `context` field for injection
- **Can block:** No (informational only)

### ConfigChange Hooks
- **Trigger:** When agent attempts to modify settings
- **Can block:** Yes (exit 2 prevents configuration changes)

## Generated vs Custom Hooks

| Type | Header | Checksum tracked | Upgraded by `right-hooks upgrade` |
|------|--------|-----------------|---------------------------|
| Generated | `# Right Hooks GENERATED — do not edit` | Yes | Yes (auto-updated) |
| Custom | Any other header or none | No | No (preserved) |

When `right-hooks upgrade` runs, it checks the checksum of each installed hook against
`.right-hooks/.checksums`. If a hook's checksum doesn't match (user modified it), the
hook is treated as custom and preserved during upgrades.

## Override Mechanism

Any gate can be overridden with an audited reason:

```bash
npx right-hooks override --gate=<gate> --reason="<reason>"
```

This creates a JSON file in `.right-hooks/.overrides/` that is committed to git,
providing a visible audit trail in the PR diff. Hooks check for override
files before blocking.

## Portability (v1.3 Roadmap)

When Right Hooks adds support for other agent runtimes (Cursor, Codex, Aider),
adapters will translate each runtime's native hook format to/from this contract.
The hooks themselves won't change — only the adapter layer between the runtime
and the hooks.
