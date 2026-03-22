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
  rh_block "pre-push" "direct push to ${BRANCH} blocked"
  echo "All changes must go through a PR. Create a branch first:" >&2
  echo "  git checkout -b feat/your-feature" >&2
  echo "  git push -u origin feat/your-feature" >&2
  echo "  gh pr create" >&2
  exit 2
fi

rh_pass "pre-push" "branch ok (${BRANCH})"
exit 0
