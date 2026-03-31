#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# PreToolUse (CronCreate|CronDelete|RemoteTrigger) hook: blocks agent self-scheduling
#
# Agents should not schedule their own future runs without human approval.
# CronCreate, CronDelete, and RemoteTrigger tools allow agents to set up
# autonomous execution. This hook blocks all three.
#
# Users who need these tools can override:
#   npx right-hooks override --gate=scheduling --reason="..."

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

INPUT=$(cat)

# Check for override
PR_NUM=$(rh_pr_number 2>/dev/null || echo "")
if [ -n "$PR_NUM" ] && rh_has_override "scheduling" "$PR_NUM"; then
  rh_debug "block-scheduling" "override found — allowing"
  exit 0
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

rh_block_start "block-scheduling"
rh_block_item "Agents cannot schedule autonomous runs ($TOOL_NAME)"
rh_block_item "This prevents unreviewed future execution"
rh_block_end "Ask user: npx right-hooks override --gate=scheduling --reason=\"...\""
exit 2
