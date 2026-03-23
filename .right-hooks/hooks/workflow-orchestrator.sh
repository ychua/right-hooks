#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# PostToolUse workflow orchestrator: injects next-step instructions via systemMessage
# Detects workflow-significant Bash commands and guides agents through the lifecycle
#
# This hook is NON-BLOCKING (always exit 0). It provides guidance, not enforcement.
# Gate-based hooks (stop-check, pre-merge) remain the safety net.
#
# State machine:
#   pr_created → review_done → qa_done → docs_done → learnings_done
#                                                          │
#                                                          ▼
#                                                    (terminal: no output)

# --- Fast-exit layer 0: reject non-Bash tools before sourcing preamble ---
# Read stdin into a variable (we need it later if we proceed)
_RH_ORCH_INPUT=$(cat)

# Quick tool_name check using grep — avoids jq + preamble for 90% of calls
if ! echo "$_RH_ORCH_INPUT" | grep -q '"tool_name"[[:space:]]*:[[:space:]]*"Bash"'; then
  exit 0
fi

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

# --- Fast-exit layer 1: extract command and check trigger patterns ---
COMMAND=$(echo "$_RH_ORCH_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
if [ -z "$COMMAND" ]; then
  exit 0
fi

# Check if command matches any trigger pattern
# Fix 4A: sentinel triggers require write operators (>, >>, tee) to prevent
# false triggers from cat/rm/grep on sentinel filenames
TRIGGERED=""
case "$COMMAND" in
  *"gh pr create"*)   TRIGGERED="pr_create" ;;
  *"gh pr comment"*)  TRIGGERED="pr_comment" ;;
esac

# Sentinel write detection: require a write operator alongside the filename
if [ -z "$TRIGGERED" ]; then
  if echo "$COMMAND" | grep -qE '(>|>>|tee)\s*.*\.(review-comment-id|qa-comment-id|doc-comment-id)'; then
    TRIGGERED="sentinel_write"
  elif echo "$COMMAND" | grep -qE '(>|>>|tee)\s*.*\.skill-proof-'; then
    TRIGGERED="provenance_write"
  elif echo "$COMMAND" | grep -qE '(>|>>|tee)\s*.*docs/retros/.*-learnings\.md'; then
    TRIGGERED="learnings_write"
  fi
fi

if [ -z "$TRIGGERED" ]; then
  exit 0
fi

rh_debug "orchestrator" "trigger=$TRIGGERED command=$(echo "$COMMAND" | head -c 80)"

# --- Fast-exit layer 2: branch-type and profile check ---
BRANCH_TYPE=$(rh_branch_type)
CODE_REVIEW_TYPES="feat fix test refactor perf ci"
if ! echo "$CODE_REVIEW_TYPES" | grep -qw "$BRANCH_TYPE"; then
  rh_debug "orchestrator" "skipping — branch type $BRANCH_TYPE not in code-review set"
  exit 0
fi

rh_match_profile "$BRANCH_TYPE"
STOP_ENABLED=$(rh_gate_value "stopHook")
if [ "$STOP_ENABLED" != "true" ]; then
  rh_debug "orchestrator" "skipping — stopHook not enabled for $BRANCH_TYPE"
  exit 0
fi

# --- Workflow state management ---
STATE_FILE=".right-hooks/.workflow-state"

read_workflow_state() {
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    echo '{"pr_created":false,"review_done":false,"qa_done":false,"docs_done":false,"learnings_done":false}'
  fi
}

write_workflow_state() {
  local new_state="$1"
  mkdir -p "$(dirname "$STATE_FILE")"
  echo "$new_state" > "$STATE_FILE"
}

state_is_done() {
  local state="$1"
  local key="$2"
  local val
  val=$(echo "$state" | jq -r ".$key // false" 2>/dev/null)
  [ "$val" = "true" ]
}

state_set_done() {
  local state="$1"
  local key="$2"
  echo "$state" | jq --arg k "$key" '.[$k] = true' 2>/dev/null
}

# --- Build systemMessage for the next required step ---
# Fix 1A: orchestrator only tells the agent WHAT to do (spawn subagent),
# never provides skill content. Only inject-skill.sh provides skill content.

build_next_step_message() {
  local state="$1"

  if ! state_is_done "$state" "review_done"; then
    cat <<'SYSMSG'
The PR has been created. The next required step is **code review**.

Spawn the 'reviewer' agent to perform code review. The agent will:
1. Analyze the diff for issues
2. Post findings as a PR comment
3. Write the sentinel file (.right-hooks/.review-comment-id)
4. Write provenance (.right-hooks/.skill-proof-codeReview)

Do NOT perform the review yourself — dispatch the 'reviewer' subagent.
SYSMSG
    return
  fi

  if ! state_is_done "$state" "qa_done"; then
    cat <<'SYSMSG'
Code review is complete. The next required step is **QA testing**.

Spawn the 'qa-reviewer' agent to perform QA. The agent will:
1. Run the test suite and analyze results
2. Post findings as a PR comment
3. Write the sentinel file (.right-hooks/.qa-comment-id)
4. Write provenance (.right-hooks/.skill-proof-qa)

Do NOT perform QA yourself — dispatch the 'qa-reviewer' subagent.
SYSMSG
    return
  fi

  if ! state_is_done "$state" "docs_done"; then
    cat <<'SYSMSG'
Review and QA are complete. The next required step is **documentation consistency**.

Spawn the 'doc-reviewer' agent to check documentation. The agent will:
1. Cross-reference code changes against documentation
2. Post findings as a PR comment
3. Write the sentinel file (.right-hooks/.doc-comment-id)
4. Write provenance (.right-hooks/.skill-proof-docConsistency)

Do NOT check docs yourself — dispatch the 'doc-reviewer' subagent.
SYSMSG
    return
  fi

  if ! state_is_done "$state" "learnings_done"; then
    cat <<'SYSMSG'
Review, QA, and docs are complete. The next required step is **learnings**.

Create a learnings document at docs/retros/<feature>-learnings.md using the template at .right-hooks/templates/learnings.md.

Each agent section must include a `### Rules to Extract` with actionable one-line rules.
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
    NEW_STATE=$(state_set_done "$STATE" "pr_created")
    write_workflow_state "$NEW_STATE"

    MESSAGE=$(build_next_step_message "$NEW_STATE" "$TRIGGERED")
    if [ -n "$MESSAGE" ]; then
      jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg}'
    fi
    ;;

  sentinel_write)
    NEW_STATE="$STATE"

    if echo "$COMMAND" | grep -qE '(>|>>|tee)\s*.*\.review-comment-id'; then
      NEW_STATE=$(state_set_done "$NEW_STATE" "review_done")
      rh_debug "orchestrator" "review sentinel detected"
    fi

    if echo "$COMMAND" | grep -qE '(>|>>|tee)\s*.*\.qa-comment-id'; then
      NEW_STATE=$(state_set_done "$NEW_STATE" "qa_done")
      rh_debug "orchestrator" "qa sentinel detected"
    fi

    if echo "$COMMAND" | grep -qE '(>|>>|tee)\s*.*\.doc-comment-id'; then
      NEW_STATE=$(state_set_done "$NEW_STATE" "docs_done")
      rh_debug "orchestrator" "doc sentinel detected"
    fi

    write_workflow_state "$NEW_STATE"

    if [ "$NEW_STATE" != "$STATE" ]; then
      MESSAGE=$(build_next_step_message "$NEW_STATE" "$TRIGGERED")
      if [ -n "$MESSAGE" ]; then
        jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg}'
      fi
    fi
    ;;

  provenance_write)
    rh_debug "orchestrator" "skill provenance file detected"
    ;;

  learnings_write)
    NEW_STATE=$(state_set_done "$STATE" "learnings_done")
    write_workflow_state "$NEW_STATE"
    rh_debug "orchestrator" "learnings file detected"
    # Terminal state — no next step to inject
    ;;

  pr_comment)
    # Nudge toward sentinel protocol if any gate is incomplete
    if ! state_is_done "$STATE" "review_done" || ! state_is_done "$STATE" "qa_done" || ! state_is_done "$STATE" "docs_done"; then
      MESSAGE="You just posted a PR comment. Remember to write the sentinel file so Right Hooks can verify it:
- Review: echo \"\$COMMENT_ID\" > .right-hooks/.review-comment-id
- QA: echo \"\$COMMENT_ID\" > .right-hooks/.qa-comment-id
- Docs: echo \"\$COMMENT_ID\" > .right-hooks/.doc-comment-id

Also write the skill provenance file (e.g., echo \"/review\" > .right-hooks/.skill-proof-codeReview)."
      jq -n --arg msg "$MESSAGE" '{"systemMessage": $msg}'
    fi
    ;;
esac

exit 0
