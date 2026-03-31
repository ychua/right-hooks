#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# SubagentStart hook: injects skill-specific instructions into subagents
# Maps agent types to configured skills and injects the skill content
#
# When a subagent starts, this hook checks if it's a Right Hooks agent
# (reviewer, qa-reviewer, doc-reviewer) by resolving agent_type against
# skills.json agentTypes arrays. If matched, it reads the configured
# skill and injects the full SKILL.md content as a systemMessage.
#
# Schema: SubagentStart provides {agent_type, agent_id} (not agent_name)

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

INPUT=$(cat)

# Extract agent_type from stdin JSON (official SubagentStart schema)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // ""' 2>/dev/null)
if [ -z "$AGENT_TYPE" ]; then
  exit 0
fi

rh_debug "inject-skill" "agent_type=$AGENT_TYPE"

# Resolve agent_type to gate via skills.json agentTypes (with legacy fallback)
rh_resolve_gate_for_agent_type "$AGENT_TYPE"

if [ -z "$RH_RESOLVED_GATE" ]; then
  rh_debug "inject-skill" "unknown agent_type '$AGENT_TYPE' — not injecting"
  exit 0
fi

GATE="$RH_RESOLVED_GATE"
rh_debug "inject-skill" "agent_type=$AGENT_TYPE → gate=$GATE"

# Load skill content using shared preamble helper
SKILL_CONTENT=$(rh_load_skill_content "$GATE")

if [ -z "$SKILL_CONTENT" ]; then
  exit 0
fi

# Show which skill is being injected
# _RH_SKILLS_JSON is cached by rh_load_skill_content
SKILL_NAME=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$GATE" '.[$g].skill // "generic"' 2>/dev/null)
PROVIDER=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$GATE" '.[$g].provider // "none"' 2>/dev/null)
if [ "$PROVIDER" != "none" ] && [ "$PROVIDER" != "null" ] && [ -n "$PROVIDER" ]; then
  rh_info "inject-skill" "injecting ${SKILL_NAME} (${PROVIDER}) → ${AGENT_TYPE}"
else
  rh_info "inject-skill" "injecting generic instructions → ${AGENT_TYPE}"
fi

# Output JSON with systemMessage — jq ensures proper escaping
jq -n --arg msg "$SKILL_CONTENT" '{"systemMessage": $msg}'
exit 0
