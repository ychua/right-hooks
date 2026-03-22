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

# Detect gstack and superpowers for tool-specific instructions
HAS_GSTACK=false
if [ -d ".claude/skills/gstack/" ] || [ -d "$HOME/.claude/skills/gstack/" ]; then
  HAS_GSTACK=true
fi

HAS_SUPERPOWERS=false
if [ -d ".claude/skills/superpowers/" ] || [ -d "$HOME/.claude/skills/superpowers/" ]; then
  HAS_SUPERPOWERS=true
fi

# Check: Review agent comments exist
REVIEW_PAT=$(rh_review_pattern)
REVIEW=$(echo "$RH_ALL_COMMENTS" | jq --arg pat "$REVIEW_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
if [ "$REVIEW" -eq 0 ]; then
  if [ "$HAS_GSTACK" = "true" ]; then
    BLOCKERS="${BLOCKERS}• No review comment found. Run /review to create a code review\n\n"
  elif [ "$HAS_SUPERPOWERS" = "true" ]; then
    BLOCKERS="${BLOCKERS}• No review comment found. Use superpowers:requesting-code-review to dispatch a code reviewer\n\n"
  else
    BLOCKERS="${BLOCKERS}• No review comment found. Post a code review comment on PR #${PR_NUM}\n\n"
  fi
fi

# Check: QA agent comments exist
QA_PAT=$(rh_qa_pattern)
QA=$(echo "$RH_ALL_COMMENTS" | jq --arg pat "$QA_PAT" '[.[] | select(.body | test($pat; "i"))] | length' 2>/dev/null || echo "0")
if [ "$QA" -eq 0 ]; then
  if [ "$HAS_GSTACK" = "true" ]; then
    BLOCKERS="${BLOCKERS}• No QA comment found. Run /qa to run QA\n\n"
  else
    BLOCKERS="${BLOCKERS}• No QA comment found. Post a QA comment on PR #${PR_NUM}\n\n"
  fi
fi

# Check: Learnings doc exists
LEARNINGS=$(gh pr diff "$PR_NUM" --name-only 2>/dev/null | sort -u | { grep -cE 'docs/retros/.*-learnings\.md$' || true; })
if [ "$LEARNINGS" -eq 0 ]; then
  BLOCKERS="${BLOCKERS}• No learnings document found. Create docs/retros/<feature>-learnings.md\n"
  BLOCKERS="${BLOCKERS}  Template: .right-hooks/templates/learnings.md\n\n"
fi

if [ -n "$BLOCKERS" ]; then
  rh_block_start "stop-check" "BLOCKED"
  printf "$BLOCKERS" | while IFS= read -r line; do
    [ -n "$line" ] && rh_block_item "$line"
  done
  if [ "$HAS_SUPERPOWERS" = "true" ]; then
    rh_block_item "TIP: Use verification-before-completion"
  fi
  rh_block_end "Override: npx right-hooks override"
  exit 2
fi

rh_pass "stop-check" "workflow complete on ${BRANCH}"
exit 0
