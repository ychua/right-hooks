#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Block direct pushes to master/main — all changes go through PRs

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

INPUT=$(cat)

# Only trigger on push commands
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
if ! echo "$CMD" | grep -qiE "git push"; then
  exit 0
fi

BRANCH=$(rh_branch)

if [ "$BRANCH" = "master" ] || [ "$BRANCH" = "main" ]; then
  rh_block_start "pre-push"
  rh_block_item "Direct push to ${BRANCH} is not allowed"
  rh_block_item "Create a branch first:"
  rh_block_item "  git checkout -b feat/your-feature"
  rh_block_item "  git push -u origin feat/your-feature"
  rh_block_end
  exit 2
fi

rh_pass "pre-push" "branch ok (${BRANCH})"
exit 0
