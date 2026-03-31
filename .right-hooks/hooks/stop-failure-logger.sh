#!/usr/bin/env bash
# RIGHT-HOOKS GENERATED — edits preserved on upgrade
# StopFailure hook: logs agent death events for observability
#
# When a Claude Code session ends due to an API error (rate limit,
# auth failure, server error, etc.), this hook records the failure
# to .stats for display in `npx right-hooks stats`.
#
# Non-blocking: always exits 0. This is observability, not enforcement.

RH_HOOK_SELF=$(realpath "$0" 2>/dev/null || echo "$0")
source "$(dirname "$0")/_preamble.sh"

INPUT=$(cat)

# Extract error type from StopFailure event
ERROR_TYPE=$(echo "$INPUT" | jq -r '.error // "unknown"' 2>/dev/null)
ERROR_DETAILS=$(echo "$INPUT" | jq -r '.error_details // ""' 2>/dev/null)

rh_debug "stop-failure" "error=$ERROR_TYPE details=$ERROR_DETAILS"

# Record the failure event
# gate="stop_failure" is filtered separately in stats.js (not a merge gate)
# stop_reason field carries the error type for display
rh_record_event "stop-failure-logger" "stop_failure" "fail" "$ERROR_TYPE"

exit 0
