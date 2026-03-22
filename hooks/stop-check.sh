#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Prevent agent from stopping before review/QA cycle is complete
# Blocks stop (exit 2) on code-review branches when workflow is incomplete

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

BRANCH=$(rh_branch)
BRANCH_TYPE=$(rh_branch_type)

# Only enforce on code-review branches
CODE_REVIEW_TYPES="feat fix test refactor perf ci"
if ! echo "$CODE_REVIEW_TYPES" | grep -qw "$BRANCH_TYPE"; then
  exit 0
fi

# Check if stop hook is enabled in profile
rh_match_profile "$BRANCH_TYPE"
STOP_ENABLED=$(rh_gate_value "stopHook")
if [ "$STOP_ENABLED" != "true" ]; then
  exit 0
fi

PR_NUM=$(rh_pr_number)
if [ -z "$PR_NUM" ]; then
  exit 0
fi

OWNER_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
BLOCKERS=""

# Batch-fetch all PR comments once (paginated)
RH_ALL_COMMENTS=""
if [ -n "$OWNER_REPO" ]; then
  RH_ALL_COMMENTS=$(GH_HTTP_TIMEOUT=15 gh api --paginate "repos/${OWNER_REPO}/issues/${PR_NUM}/comments" 2>/dev/null | jq -s 'add // []' 2>/dev/null || echo "[]")
fi

# Tool detection uses shared preamble helpers (rh_has_gstack, rh_has_superpowers)

# Check: Review comment exists AND was posted by a real subagent (sentinel protocol)
# Sentinel files prove a subagent actually ran and posted — prevents the orchestrating
# agent from faking review/QA comments by posting them directly.
REVIEW_SENTINEL=".right-hooks/.review-comment-id"
REVIEW_VERIFIED=false
if [ -f "$REVIEW_SENTINEL" ] && [ -n "$OWNER_REPO" ]; then
  REVIEW_CID=$(cat "$REVIEW_SENTINEL")
  REVIEW_EXISTS=$(gh api "repos/${OWNER_REPO}/issues/comments/${REVIEW_CID}" --jq '.id' 2>/dev/null || echo "")
  [ -n "$REVIEW_EXISTS" ] && REVIEW_VERIFIED=true
fi
if [ "$REVIEW_VERIFIED" != "true" ]; then
  # Fallback: check comment pattern (weaker, can be faked by orchestrator)
  REVIEW_PAT=$(rh_review_pattern)
  REVIEW=$(echo "$RH_ALL_COMMENTS" | jq --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
  if [ "$REVIEW" -eq 0 ]; then
    if rh_has_gstack; then
      BLOCKERS="${BLOCKERS}• No review comment found. Run /review to create a code review\n\n"
    elif rh_has_superpowers; then
      BLOCKERS="${BLOCKERS}• No review comment found. Use superpowers:requesting-code-review\n\n"
    else
      BLOCKERS="${BLOCKERS}• No review comment found. Post a code review comment on PR #${PR_NUM}\n\n"
    fi
  else
    BLOCKERS="${BLOCKERS}• Review comment exists but no sentinel file (.right-hooks/.review-comment-id)\n"
    BLOCKERS="${BLOCKERS}  → This means the comment may not have been posted by a real review subagent\n"
    BLOCKERS="${BLOCKERS}  → Dispatch a real reviewer: subagents must write comment ID to the sentinel file\n\n"
  fi
fi

# Check: QA comment exists AND was posted by a real subagent
QA_SENTINEL=".right-hooks/.qa-comment-id"
QA_VERIFIED=false
if [ -f "$QA_SENTINEL" ] && [ -n "$OWNER_REPO" ]; then
  QA_CID=$(cat "$QA_SENTINEL")
  QA_EXISTS=$(gh api "repos/${OWNER_REPO}/issues/comments/${QA_CID}" --jq '.id' 2>/dev/null || echo "")
  [ -n "$QA_EXISTS" ] && QA_VERIFIED=true
fi
if [ "$QA_VERIFIED" != "true" ]; then
  QA_PAT=$(rh_qa_pattern)
  QA=$(echo "$RH_ALL_COMMENTS" | jq --arg pat "$QA_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
  if [ "$QA" -eq 0 ]; then
    if rh_has_gstack; then
      BLOCKERS="${BLOCKERS}• No QA comment found. Run /qa to run QA\n\n"
    else
      BLOCKERS="${BLOCKERS}• No QA comment found. Post a QA comment on PR #${PR_NUM}\n\n"
    fi
  else
    BLOCKERS="${BLOCKERS}• QA comment exists but no sentinel file (.right-hooks/.qa-comment-id)\n"
    BLOCKERS="${BLOCKERS}  → This means the comment may not have been posted by a real QA subagent\n"
    BLOCKERS="${BLOCKERS}  → Dispatch a real QA agent: subagents must write comment ID to the sentinel file\n\n"
  fi
fi

# Check: Learnings doc exists
LEARNINGS=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | sort -u | { grep -cE 'docs/retros/.*-learnings\.md$' || true; })
if [ "$LEARNINGS" -eq 0 ]; then
  BLOCKERS="${BLOCKERS}• No learnings document found. Create docs/retros/<feature>-learnings.md\n"
  BLOCKERS="${BLOCKERS}  Template: .right-hooks/templates/learnings.md\n\n"
fi

if [ -n "$BLOCKERS" ]; then
  rh_block_start "stop-check"
  while IFS= read -r line; do
    [ -n "$line" ] && rh_block_item "$line"
  done <<< "$(printf "$BLOCKERS")"
  if rh_has_superpowers; then
    rh_block_item "TIP: Use verification-before-completion"
  fi
  rh_block_end "Override: npx right-hooks override"
  exit 2
fi

rh_pass "stop-check" "workflow complete on ${BRANCH}"
exit 0
