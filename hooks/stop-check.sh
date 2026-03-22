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
  REVIEW_BODY=$(gh api "repos/${OWNER_REPO}/issues/comments/${REVIEW_CID}" --jq '.body' 2>/dev/null || echo "")
  [ -n "$REVIEW_BODY" ] && REVIEW_VERIFIED=true
fi
REVIEW_HINT=$(rh_skill_command "codeReview" "$PR_NUM")
if [ "$REVIEW_VERIFIED" != "true" ]; then
  # Fallback: check comment pattern (weaker, can be faked by orchestrator)
  REVIEW_PAT=$(rh_review_pattern)
  REVIEW=$(echo "$RH_ALL_COMMENTS" | jq --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
  if [ "$REVIEW" -eq 0 ]; then
    BLOCKERS="${BLOCKERS}• No review comment found. ${REVIEW_HINT}\n"
    BLOCKERS="${BLOCKERS}  → Sentinel: write comment ID to .right-hooks/.review-comment-id\n"
    BLOCKERS="${BLOCKERS}  → Provenance: write skill name to .right-hooks/.skill-proof-codeReview\n\n"
  else
    BLOCKERS="${BLOCKERS}• Review comment exists but no sentinel file (.right-hooks/.review-comment-id)\n"
    BLOCKERS="${BLOCKERS}  → Dispatch a real reviewer: subagents must write comment ID to the sentinel file\n\n"
  fi
else
  # Sentinel verified — now check skill signature (Level 2)
  if ! rh_skill_signature_match "codeReview" "$REVIEW_BODY"; then
    BLOCKERS="${BLOCKERS}• Review comment doesn't match configured skill signature. ${REVIEW_HINT}\n"
    BLOCKERS="${BLOCKERS}  → The comment was not produced by the configured review skill\n\n"
  fi
  # Check provenance (Level 3)
  if ! rh_skill_provenance_check "codeReview"; then
    BLOCKERS="${BLOCKERS}• No skill provenance for codeReview. ${REVIEW_HINT}\n"
    BLOCKERS="${BLOCKERS}  → After invoking the skill, write: echo \"/review\" > .right-hooks/.skill-proof-codeReview\n\n"
  fi
fi

# Check: QA comment exists AND was posted by a real subagent
QA_SENTINEL=".right-hooks/.qa-comment-id"
QA_VERIFIED=false
if [ -f "$QA_SENTINEL" ] && [ -n "$OWNER_REPO" ]; then
  QA_CID=$(cat "$QA_SENTINEL")
  QA_BODY=$(gh api "repos/${OWNER_REPO}/issues/comments/${QA_CID}" --jq '.body' 2>/dev/null || echo "")
  [ -n "$QA_BODY" ] && QA_VERIFIED=true
fi
QA_HINT=$(rh_skill_command "qa" "$PR_NUM")
if [ "$QA_VERIFIED" != "true" ]; then
  QA_PAT=$(rh_qa_pattern)
  QA=$(echo "$RH_ALL_COMMENTS" | jq --arg pat "$QA_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
  if [ "$QA" -eq 0 ]; then
    BLOCKERS="${BLOCKERS}• No QA comment found. ${QA_HINT}\n"
    BLOCKERS="${BLOCKERS}  → Sentinel: write comment ID to .right-hooks/.qa-comment-id\n"
    BLOCKERS="${BLOCKERS}  → Provenance: write skill name to .right-hooks/.skill-proof-qa\n\n"
  else
    BLOCKERS="${BLOCKERS}• QA comment exists but no sentinel file (.right-hooks/.qa-comment-id)\n"
    BLOCKERS="${BLOCKERS}  → Dispatch a real QA agent: subagents must write comment ID to the sentinel file\n\n"
  fi
else
  # Sentinel verified — check skill signature (Level 2)
  if ! rh_skill_signature_match "qa" "$QA_BODY"; then
    BLOCKERS="${BLOCKERS}• QA comment doesn't match configured skill signature. ${QA_HINT}\n"
    BLOCKERS="${BLOCKERS}  → The comment was not produced by the configured QA skill\n\n"
  fi
  # Check provenance (Level 3)
  if ! rh_skill_provenance_check "qa"; then
    BLOCKERS="${BLOCKERS}• No skill provenance for qa. ${QA_HINT}\n"
    BLOCKERS="${BLOCKERS}  → After invoking the skill, write: echo \"/qa\" > .right-hooks/.skill-proof-qa\n\n"
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
