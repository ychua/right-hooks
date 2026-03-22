#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Verify subagent actually produced artifacts (anti-gaming)
# Uses sentinel file protocol (.right-hooks/.last-review-comment-id) — NOT time-window

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
SENTINEL=".right-hooks/.last-review-comment-id"
if [ -f "$SENTINEL" ]; then
  COMMENT_ID=$(cat "$SENTINEL")
  # Verify the comment actually exists on the PR
  EXISTS=$(gh api "repos/${OWNER_REPO}/issues/comments/${COMMENT_ID}" --jq '.id' 2>/dev/null || echo "")
  if [ -n "$EXISTS" ]; then
    rm -f "$SENTINEL"
    exit 0  # Verified — real comment posted by subagent
  fi
fi

# No sentinel or invalid — check if this was a review/QA subagent
SUBAGENT_OUTPUT=$(echo "$INPUT" | jq -r '.output // ""' 2>/dev/null)
REVIEW_PAT=$(rh_review_pattern)
QA_PAT=$(rh_qa_pattern)
if echo "$SUBAGENT_OUTPUT" | grep -qiE "${REVIEW_PAT}|${QA_PAT}|code review|quality assurance"; then
  echo "RIGHT-HOOKS: Review/QA subagent finished but no verified PR comment found." >&2
  echo "" >&2
  echo "Subagents must:" >&2
  echo "  1. Post findings via: gh pr comment $PR_NUM --body '...'" >&2
  echo "  2. Write comment ID to .right-hooks/.last-review-comment-id" >&2
  echo "" >&2
  echo "Example:" >&2
  echo "  COMMENT_URL=\$(gh pr comment $PR_NUM --body \"\$FINDINGS\" 2>&1)" >&2
  echo "  COMMENT_ID=\$(echo \"\$COMMENT_URL\" | grep -oE '[0-9]+\$')" >&2
  echo "  echo \"\$COMMENT_ID\" > .right-hooks/.last-review-comment-id" >&2
  exit 2
fi

exit 0
