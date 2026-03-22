#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Inject project context when a Claude Code session begins
# Provides branch status, PR info, and gate satisfaction

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

BRANCH=$(rh_branch)
if [ -z "$BRANCH" ]; then
  BRANCH="unknown"
fi

PR_NUM=$(rh_pr_number)
OWNER_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")

STATUS=""

if [ -n "$PR_NUM" ]; then
  # Check gate satisfaction
  CI_FAILING=$(gh pr checks "$PR_NUM" 2>/dev/null | grep -cE "fail|pending" || echo "?")
  REVIEW_PAT=$(rh_review_pattern)
  QA_PAT=$(rh_qa_pattern)
  REVIEW_COUNT=$(gh api "repos/${OWNER_REPO}/issues/${PR_NUM}/comments" \
    --jq --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
  QA_COUNT=$(gh api "repos/${OWNER_REPO}/issues/${PR_NUM}/comments" \
    --jq --arg pat "$QA_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
  UNCHECKED_DOD=$(gh pr view "$PR_NUM" --json body --jq '.body' 2>/dev/null | grep -c '- \[ \]' || echo "0")

  STATUS="Branch: $BRANCH | PR: #$PR_NUM | CI failing: $CI_FAILING | Reviews: $REVIEW_COUNT | QA: $QA_COUNT | Unchecked DoD: $UNCHECKED_DOD"
  
  # Check for active overrides
  OVERRIDE_COUNT=$(ls .right-hooks/.overrides/*-PR${PR_NUM}.json 2>/dev/null | wc -l | tr -d ' ')
  if [ "$OVERRIDE_COUNT" -gt 0 ]; then
    STATUS="$STATUS | Overrides: $OVERRIDE_COUNT"
  fi
else
  STATUS="Branch: $BRANCH | No open PR"
fi

# Include active profile and preset
PRESET=$(cat .right-hooks/active-preset.json 2>/dev/null | jq -r '.language // "unknown"' 2>/dev/null || echo "unknown")
PROFILE=$(cat .right-hooks/active-profile.json 2>/dev/null | jq -r '.name // "unknown"' 2>/dev/null || echo "unknown")

STATUS="$STATUS | Preset: $PRESET | Profile: $PROFILE"

# Output as context injection
rh_info "session-start" "${PROFILE} profile | ${PRESET} preset | ${BRANCH}"
echo "{\"context\": \"$STATUS\"}"
exit 0
