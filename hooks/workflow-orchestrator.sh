#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# PostToolUse workflow orchestrator: injects next-step instructions via systemMessage
# Detects workflow-significant Bash commands and guides agents through the lifecycle
#
# This hook is NON-BLOCKING (always exit 0). It provides guidance, not enforcement.
# Gate-based hooks (stop-check, pre-merge) remain the safety net.

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

# Read stdin once — this fires on EVERY tool call, so speed matters
INPUT=$(cat)

# --- Fast-exit layer 1: only care about Bash tool ---
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# --- Fast-exit layer 2: quick command pattern match ---
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Check if command matches any trigger pattern (fast string checks before regex)
TRIGGERED=""
case "$COMMAND" in
  *"gh pr create"*)   TRIGGERED="pr_create" ;;
  *".review-comment-id"*|*".qa-comment-id"*|*".skill-proof-"*) TRIGGERED="sentinel_write" ;;
  *"gh pr comment"*)  TRIGGERED="pr_comment" ;;
esac

if [ -z "$TRIGGERED" ]; then
  exit 0
fi

rh_debug "orchestrator" "trigger=$TRIGGERED command=$(echo "$COMMAND" | head -c 80)"

# --- Branch-type check: only activate on code-review branches ---
BRANCH_TYPE=$(rh_branch_type)
CODE_REVIEW_TYPES="feat fix test refactor perf ci"
if ! echo "$CODE_REVIEW_TYPES" | grep -qw "$BRANCH_TYPE"; then
  rh_debug "orchestrator" "skipping — branch type $BRANCH_TYPE not in code-review set"
  exit 0
fi

# --- Profile check: only activate when stopHook is enabled ---
rh_match_profile "$BRANCH_TYPE"
STOP_ENABLED=$(rh_gate_value "stopHook")
if [ "$STOP_ENABLED" != "true" ]; then
  rh_debug "orchestrator" "skipping — stopHook not enabled for $BRANCH_TYPE"
  exit 0
fi

# --- Workflow state management ---
STATE_FILE=".right-hooks/.workflow-state"

# Read current workflow state (creates default if missing)
read_workflow_state() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    echo '{"pr_created":false,"review_done":false,"qa_done":false,"learnings_done":false,"docs_done":false}'
  fi
}

# Write updated workflow state (immutable — writes new file)
write_workflow_state() {
  local new_state="$1"
  mkdir -p "$(dirname "$STATE_FILE")"
  echo "$new_state" > "$STATE_FILE"
}

# Check if a state flag is true
state_is_done() {
  local state="$1"
  local key="$2"
  local val
  val=$(echo "$state" | jq -r ".$key // false" 2>/dev/null)
  [ "$val" = "true" ]
}

# Set a state flag to true (returns new state)
state_set_done() {
  local state="$1"
  local key="$2"
  echo "$state" | jq --arg k "$key" '.[$k] = true' 2>/dev/null
}

# --- Skill content loading ---

# Load skill file content for a gate (e.g., "codeReview" -> /review skill content)
# Falls back to the fallback text from skills.json if skill file not found
load_skill_content() {
  local gate="$1"

  # Load skills.json (uses cached preamble mechanism)
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
      rh_debug "orchestrator" "loaded skill content from $skill_file"
      cat "$skill_file"
      return
    fi
  fi

  # Fallback: use the fallback text from skills.json
  local fallback pr_num
  pr_num=$(rh_pr_number)
  fallback=$(echo "$_RH_SKILLS_JSON" | jq -r --arg g "$gate" '.[$g].fallback // empty' 2>/dev/null)
  if [ -n "$fallback" ]; then
    echo "${fallback//\$\{PR_NUM\}/$pr_num}"
    return
  fi

  # Last resort
  echo "Complete the $gate step for this PR."
}

# --- Build systemMessage for the next required step ---

build_next_step_message() {
  local state="$1"
  local trigger="$2"

  # Determine what's next based on what's already done
  if ! state_is_done "$state" "review_done"; then
    local skill_content
    skill_content=$(load_skill_content "codeReview")
    local review_cmd
    review_cmd=$(rh_skill_command "codeReview")
    cat <<SYSMSG
The PR has been created. The next required step is **code review**.

You MUST dispatch a code review before proceeding. ${review_cmd}

After the review subagent posts its comment, write the sentinel and provenance files:
\`\`\`bash
COMMENT_URL=\$(gh pr comment \$PR_NUM --body "\$FINDINGS" 2>&1)
COMMENT_ID=\$(echo "\$COMMENT_URL" | grep -oE '[0-9]+\$')
echo "\$COMMENT_ID" > .right-hooks/.review-comment-id
echo "/review" > .right-hooks/.skill-proof-codeReview
\`\`\`

---

${skill_content}
SYSMSG
    return
  fi

  if ! state_is_done "$state" "qa_done"; then
    local skill_content
    skill_content=$(load_skill_content "qa")
    local qa_cmd
    qa_cmd=$(rh_skill_command "qa")
    cat <<SYSMSG
Code review is complete. The next required step is **QA testing**.

You MUST dispatch QA testing before proceeding. ${qa_cmd}

After the QA subagent posts its comment, write the sentinel and provenance files:
\`\`\`bash
COMMENT_URL=\$(gh pr comment \$PR_NUM --body "\$FINDINGS" 2>&1)
COMMENT_ID=\$(echo "\$COMMENT_URL" | grep -oE '[0-9]+\$')
echo "\$COMMENT_ID" > .right-hooks/.qa-comment-id
echo "/qa" > .right-hooks/.skill-proof-qa
\`\`\`

---

${skill_content}
SYSMSG
    return
  fi

  if ! state_is_done "$state" "learnings_done"; then
    cat <<SYSMSG
Review and QA are complete. The next required step is **learnings**.

Create a learnings document at docs/retros/<feature>-learnings.md using the template at .right-hooks/templates/learnings.md.

Each agent section must include a \`### Rules to Extract\` with actionable one-line rules.
SYSMSG
    return
  fi

  # Everything done — no message needed
  echo ""
}

# --- Main trigger handling ---

STATE=$(read_workflow_state)

case "$TRIGGERED" in
  pr_create)
    # PR was just created — mark state, inject next step
    NEW_STATE=$(state_set_done "$STATE" "pr_created")
    write_workflow_state "$NEW_STATE"

    MESSAGE=$(build_next_step_message "$NEW_STATE" "$TRIGGERED")
    if [ -n "$MESSAGE" ]; then
      # Output JSON with systemMessage — jq ensures proper escaping
      jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg}'
    fi
    ;;

  sentinel_write)
    # A sentinel or provenance file was written — update state accordingly
    NEW_STATE="$STATE"

    if echo "$COMMAND" | grep -q ".review-comment-id"; then
      NEW_STATE=$(state_set_done "$NEW_STATE" "review_done")
      rh_debug "orchestrator" "review sentinel detected"
    fi

    if echo "$COMMAND" | grep -q ".qa-comment-id"; then
      NEW_STATE=$(state_set_done "$NEW_STATE" "qa_done")
      rh_debug "orchestrator" "qa sentinel detected"
    fi

    if echo "$COMMAND" | grep -q ".skill-proof-"; then
      rh_debug "orchestrator" "skill provenance file detected"
    fi

    write_workflow_state "$NEW_STATE"

    # Inject next step if state changed
    if [ "$NEW_STATE" != "$STATE" ]; then
      MESSAGE=$(build_next_step_message "$NEW_STATE" "$TRIGGERED")
      if [ -n "$MESSAGE" ]; then
        jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg}'
      fi
    fi
    ;;

  pr_comment)
    # A PR comment was posted — check if it's review or QA related
    # We don't update state here because sentinels are the authoritative signal.
    # But we can nudge toward the sentinel protocol if state is incomplete.
    if ! state_is_done "$STATE" "review_done" && ! state_is_done "$STATE" "qa_done"; then
      MESSAGE="You just posted a PR comment. Remember to write the sentinel file so Right Hooks can verify it:
- Review: echo \"\$COMMENT_ID\" > .right-hooks/.review-comment-id
- QA: echo \"\$COMMENT_ID\" > .right-hooks/.qa-comment-id

Also write the skill provenance file (e.g., echo \"/review\" > .right-hooks/.skill-proof-codeReview)."
      jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg}'
    fi
    ;;
esac

exit 0
