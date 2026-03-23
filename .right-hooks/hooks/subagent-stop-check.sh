#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Verify subagent actually produced artifacts (anti-gaming)
# Uses sentinel file protocol — subagents write comment IDs to:
#   .right-hooks/.review-comment-id  (code review)
#   .right-hooks/.qa-comment-id      (QA)
#   .right-hooks/.doc-comment-id     (documentation)

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

INPUT=$(cat)

BRANCH=$(rh_branch)
PR_NUM=$(rh_pr_number)

if [ -z "$PR_NUM" ]; then
  exit 0
fi

OWNER_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")

# Check if a sentinel file was written by the subagent
# Accept both the canonical names and the legacy name
VERIFIED=false
for sentinel in .right-hooks/.review-comment-id .right-hooks/.qa-comment-id .right-hooks/.doc-comment-id; do
  if [ -f "$sentinel" ]; then
    COMMENT_ID=$(cat "$sentinel")
    EXISTS=$(gh api "repos/${OWNER_REPO}/issues/comments/${COMMENT_ID}" --jq '.id' 2>/dev/null || echo "")
    if [ -n "$EXISTS" ]; then
      VERIFIED=true
      break
    fi
  fi
done

if [ "$VERIFIED" = "true" ]; then
  rh_pass "subagent-check" "comment verified via sentinel"
  exit 0
fi

# No sentinel or invalid — check if this was a review/QA subagent
SUBAGENT_OUTPUT=$(echo "$INPUT" | jq -r '.output // ""' 2>/dev/null)
REVIEW_PAT=$(rh_review_pattern)
QA_PAT=$(rh_qa_pattern)
DOC_PAT=$(rh_doc_pattern)
if echo "$SUBAGENT_OUTPUT" | grep -qiE "${REVIEW_PAT}|${QA_PAT}|${DOC_PAT}|code review|quality assurance|documentation"; then
  rh_block_start "subagent-check"
  rh_block_item "No verified PR comment found"
  rh_block_item ""
  rh_block_item "Subagents must:"
  rh_block_item "  1. Post via: gh pr comment \$PR --body '...'"
  rh_block_item "  2. Write ID to sentinel file:"
  rh_block_item "     .right-hooks/.review-comment-id (review)"
  rh_block_item "     .right-hooks/.qa-comment-id (QA)"
  rh_block_item "     .right-hooks/.doc-comment-id (docs)"
  rh_block_end
  exit 2
fi

rh_pass "subagent-check" "output verified"
exit 0
