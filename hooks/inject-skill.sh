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

# Load skill content for this gate
# Reuses the same lookup logic as the workflow orchestrator:
#   1. Read skills.json for configured skill + provider
#   2. Search for SKILL.md in project-local and home skill directories
#   3. Fall back to fallback text from skills.json
#   4. Last resort: generic message

load_skill_content() {
  local gate="$1"

  # Load and cache skills.json
  if [ -z "$_RH_SKILLS_LOADED" ]; then
    _RH_SKILLS_JSON=$(cat .right-hooks/skills.json 2>/dev/null || echo "{}")
    _RH_SKILLS_LOADED=1
  fi

  local skill provider
  skill=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].skill // empty' 2>/dev/null)
  provider=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].provider // empty' 2>/dev/null)

  # Try to read the actual skill file
  if [ -n "$skill" ] && [ -n "$provider" ]; then
    local skill_file=""
    local skill_name
    skill_name=$(echo "$skill" | sed 's|^/||')

    # Check project-local then home directory
    for base_dir in ".claude/skills/${provider}" "$HOME/.claude/skills/${provider}"; do
      if [ -f "${base_dir}/SKILL.md" ]; then
        skill_file="${base_dir}/SKILL.md"
        break
      fi
      if [ -f "${base_dir}/${skill_name}/SKILL.md" ]; then
        skill_file="${base_dir}/${skill_name}/SKILL.md"
        break
      fi
    done

    if [ -n "$skill_file" ] && [ -f "$skill_file" ]; then
      rh_debug "inject-skill" "loaded skill content from $skill_file"
      cat "$skill_file"
      return
    fi
  fi

  # Fallback: use the fallback text from skills.json (with ${PR_NUM} interpolation)
  local fallback pr_num
  pr_num=$(rh_pr_number)
  fallback=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].fallback // empty' 2>/dev/null)
  if [ -n "$fallback" ]; then
    rh_debug "inject-skill" "using fallback text for gate=$gate"
    echo "${fallback//\$\{PR_NUM\}/$pr_num}"
    return
  fi

  # Last resort: generic instruction
  rh_debug "inject-skill" "no skill config for gate=$gate — using generic"
  echo "Complete the $gate step for this PR."
}

SKILL_CONTENT=$(load_skill_content "$GATE")

if [ -z "$SKILL_CONTENT" ]; then
  exit 0
fi

# Output JSON with systemMessage — jq ensures proper escaping
jq -n --arg msg "$SKILL_CONTENT" '{"systemMessage": $msg}'
exit 0
