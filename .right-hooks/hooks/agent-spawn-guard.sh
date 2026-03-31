#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# PreToolUse (Agent) hook: defense-in-depth guard for agent spawning
#
# Allow-by-default: known agent types are logged, unknown types pass through.
# Blocks dangerous patterns in agent prompts (override attempts, config
# tampering, hook directory destruction).
#
# This is a guard, not a gate — the real enforcement boundary is
# stop-check + pre-merge. This hook adds defense-in-depth.

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

INPUT=$(cat)

# Extract subagent_type from PreToolUse Agent tool_input
AGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null)
AGENT_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null)

# --- Check for dangerous patterns in agent prompt ---
if [ -n "$AGENT_PROMPT" ]; then
  if echo "$AGENT_PROMPT" | grep -qiE 'right-hooks\s+override'; then
    rh_block "agent-guard" "Agent prompt contains override attempt — blocked"
    exit 2
  fi
  if echo "$AGENT_PROMPT" | grep -qiE 'rm\s+(-rf?\s+)?\.right-hooks'; then
    rh_block "agent-guard" "Agent prompt contains .right-hooks destruction — blocked"
    exit 2
  fi
  if echo "$AGENT_PROMPT" | grep -qiE '(modify|edit|change|delete|remove)\s+.*settings\.json'; then
    rh_block "agent-guard" "Agent prompt contains settings.json modification — blocked"
    exit 2
  fi
fi

# --- Log agent type resolution ---
if [ -n "$AGENT_TYPE" ]; then
  rh_resolve_gate_for_agent_type "$AGENT_TYPE"
  if [ -n "$RH_RESOLVED_GATE" ]; then
    rh_debug "agent-guard" "agent_type=$AGENT_TYPE → gate=$RH_RESOLVED_GATE (known)"
  else
    rh_debug "agent-guard" "agent_type=$AGENT_TYPE (unknown — allowing)"
  fi
fi

exit 0
