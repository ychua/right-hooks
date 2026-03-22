#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# Blocks AI agents from calling 'right-hooks override' — only humans can override gates.
# This prevents agents from self-approving bypasses to enforcement gates.

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

if echo "$CMD" | grep -qE 'right-hooks\s+override'; then
  echo "BLOCKED: Only humans can override gates." >&2
  echo "Ask the user to run: npx right-hooks override --gate=<gate> --reason=\"...\"" >&2
  exit 2
fi

exit 0
