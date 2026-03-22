#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Blocks AI agents from calling 'right-hooks override' — only humans can override gates.
# This prevents agents from self-approving bypasses to enforcement gates.

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

if echo "$CMD" | grep -qE 'right-hooks\s+override'; then
  rh_block "block-override" "only humans can override gates"
  echo "Ask the user to run: npx right-hooks override --gate=<gate> --reason=\"...\"" >&2
  exit 2
fi

exit 0
