#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# SubagentStart hook: injects skill-specific instructions into subagents
# Maps agent names to configured skills and injects the skill content
#
# When a subagent starts, this hook checks if it's a Right Hooks agent
# (reviewer, qa-reviewer, doc-reviewer). If so, it reads the configured
# skill from skills.json and injects the full SKILL.md content as a
# systemMessage. This ensures the subagent runs the real skill workflow
# rather than a generic approximation.

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

INPUT=$(cat)

# Extract agent name from stdin JSON
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // ""' 2>/dev/null)
if [ -z "$AGENT_NAME" ]; then
  exit 0
fi

rh_debug "inject-skill" "agent=$AGENT_NAME"

# Map agent names to skill gates
# Supports canonical names and common aliases
GATE=""
case "$AGENT_NAME" in
  reviewer|code-reviewer|review)   GATE="codeReview" ;;
  qa-reviewer|qa|qa-tester)        GATE="qa" ;;
  doc-reviewer|doc-checker)        GATE="docConsistency" ;;
esac

if [ -z "$GATE" ]; then
  rh_debug "inject-skill" "unknown agent '$AGENT_NAME' — not injecting"
  exit 0
fi

rh_debug "inject-skill" "agent=$AGENT_NAME → gate=$GATE"

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
  rh_info "inject-skill" "injecting ${SKILL_NAME} (${PROVIDER}) → ${AGENT_NAME}"
else
  rh_info "inject-skill" "injecting generic instructions → ${AGENT_NAME}"
fi

# Output JSON with systemMessage — jq ensures proper escaping
jq -n --arg msg "$SKILL_CONTENT" '{"systemMessage": $msg}'
exit 0
