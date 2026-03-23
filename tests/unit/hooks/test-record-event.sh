#!/usr/bin/env bash
# Tests for: rh_record_event function in _preamble.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

PREAMBLE="$(cd "$SCRIPT_DIR/../../../" && pwd)/hooks/_preamble.sh"

cd "$TEST_TMPDIR"
git init -q
mkdir -p .right-hooks/hooks
cp "$PREAMBLE" .right-hooks/hooks/_preamble.sh

# Source preamble in test mode
export RH_TEST=1
source .right-hooks/hooks/_preamble.sh

# --- rh_record_event creates .stats directory ---
describe "rh_record_event creates .stats directory if missing"
rh_record_event "test-hook" "testGate" "pass"
assert_dir_exists ".right-hooks/.stats"

# --- rh_record_event writes valid JSON line ---
describe "rh_record_event writes valid JSONL"
LAST_LINE=$(tail -1 .right-hooks/.stats/events.jsonl)
echo "$LAST_LINE" | jq -e . >/dev/null 2>&1
assert_exit_code 0 $?

# --- event has required fields ---
describe "event has ts, hook, gate, result, branch fields"
LAST_LINE=$(tail -1 .right-hooks/.stats/events.jsonl)
HAS_TS=$(echo "$LAST_LINE" | jq -e '.ts' >/dev/null 2>&1 && echo "1" || echo "0")
HAS_HOOK=$(echo "$LAST_LINE" | jq -e '.hook' >/dev/null 2>&1 && echo "1" || echo "0")
HAS_GATE=$(echo "$LAST_LINE" | jq -e '.gate' >/dev/null 2>&1 && echo "1" || echo "0")
HAS_RESULT=$(echo "$LAST_LINE" | jq -e '.result' >/dev/null 2>&1 && echo "1" || echo "0")
HAS_BRANCH=$(echo "$LAST_LINE" | jq -e '.branch' >/dev/null 2>&1 && echo "1" || echo "0")
if [ "$HAS_TS" = "1" ] && [ "$HAS_HOOK" = "1" ] && [ "$HAS_GATE" = "1" ] && [ "$HAS_RESULT" = "1" ] && [ "$HAS_BRANCH" = "1" ]; then
  pass
else
  fail "Missing required fields in event JSON"
fi

# --- optional pr field included when passed ---
describe "event includes pr field when provided"
rh_record_event "test-hook" "testGate" "block" "" "42"
LAST_LINE=$(tail -1 .right-hooks/.stats/events.jsonl)
PR_VAL=$(echo "$LAST_LINE" | jq -r '.pr')
if [ "$PR_VAL" = "42" ]; then
  pass
else
  fail "Expected pr=42, got $PR_VAL"
fi

# --- optional pr field omitted when empty ---
describe "event omits pr field when not provided"
rh_record_event "test-hook" "testGate" "pass"
LAST_LINE=$(tail -1 .right-hooks/.stats/events.jsonl)
HAS_PR=$(echo "$LAST_LINE" | jq 'has("pr")')
if [ "$HAS_PR" = "false" ]; then
  pass
else
  fail "Expected no pr field, but it was present"
fi

# --- optional stop_reason field ---
describe "event includes stop_reason when provided"
rh_record_event "stop-check" "stop" "pass" "pipeline_complete"
LAST_LINE=$(tail -1 .right-hooks/.stats/events.jsonl)
REASON=$(echo "$LAST_LINE" | jq -r '.stop_reason')
if [ "$REASON" = "pipeline_complete" ]; then
  pass
else
  fail "Expected stop_reason=pipeline_complete, got $REASON"
fi

# --- rh_pass with 3rd arg auto-records ---
describe "rh_pass with gate arg auto-records pass event"
COUNT_BEFORE=$(wc -l < .right-hooks/.stats/events.jsonl | tr -d ' ')
rh_pass "post-edit-check" "validation passed" "postEditCheck"
COUNT_AFTER=$(wc -l < .right-hooks/.stats/events.jsonl | tr -d ' ')
DIFF=$((COUNT_AFTER - COUNT_BEFORE))
if [ "$DIFF" -eq 1 ]; then
  LAST_LINE=$(tail -1 .right-hooks/.stats/events.jsonl)
  RESULT=$(echo "$LAST_LINE" | jq -r '.result')
  GATE=$(echo "$LAST_LINE" | jq -r '.gate')
  if [ "$RESULT" = "pass" ] && [ "$GATE" = "postEditCheck" ]; then
    pass
  else
    fail "Expected result=pass gate=postEditCheck, got result=$RESULT gate=$GATE"
  fi
else
  fail "Expected 1 new event, got $DIFF"
fi

# --- rh_pass without 3rd arg does NOT record ---
describe "rh_pass without gate arg does not record"
COUNT_BEFORE=$(wc -l < .right-hooks/.stats/events.jsonl | tr -d ' ')
rh_pass "pre-merge" "all gates passed"
COUNT_AFTER=$(wc -l < .right-hooks/.stats/events.jsonl | tr -d ' ')
DIFF=$((COUNT_AFTER - COUNT_BEFORE))
if [ "$DIFF" -eq 0 ]; then
  pass
else
  fail "Expected 0 new events, got $DIFF"
fi

# --- rh_block with 3rd arg auto-records ---
describe "rh_block with gate arg auto-records block event"
COUNT_BEFORE=$(wc -l < .right-hooks/.stats/events.jsonl | tr -d ' ')
rh_block "post-edit-check" "validation failed" "postEditCheck"
COUNT_AFTER=$(wc -l < .right-hooks/.stats/events.jsonl | tr -d ' ')
DIFF=$((COUNT_AFTER - COUNT_BEFORE))
if [ "$DIFF" -eq 1 ]; then
  LAST_LINE=$(tail -1 .right-hooks/.stats/events.jsonl)
  RESULT=$(echo "$LAST_LINE" | jq -r '.result')
  if [ "$RESULT" = "block" ]; then
    pass
  else
    fail "Expected result=block, got $RESULT"
  fi
else
  fail "Expected 1 new event, got $DIFF"
fi

# --- RH_QUIET suppresses display but recording still works ---
describe "RH_QUIET=1 suppresses display but still records"
COUNT_BEFORE=$(wc -l < .right-hooks/.stats/events.jsonl | tr -d ' ')
RH_QUIET=1 rh_pass "test-hook" "quiet message" "testGate"
COUNT_AFTER=$(wc -l < .right-hooks/.stats/events.jsonl | tr -d ' ')
DIFF=$((COUNT_AFTER - COUNT_BEFORE))
if [ "$DIFF" -eq 1 ]; then
  pass
else
  fail "Expected 1 event even in quiet mode, got $DIFF"
fi

# --- branch field uses cached _RH_BRANCH ---
describe "event uses cached _RH_BRANCH value"
LAST_LINE=$(tail -1 .right-hooks/.stats/events.jsonl)
BRANCH_VAL=$(echo "$LAST_LINE" | jq -r '.branch')
# In test env, we're on the default git branch (main or master)
if [ -n "$BRANCH_VAL" ] && [ "$BRANCH_VAL" != "null" ]; then
  pass
else
  fail "Expected non-empty branch, got '$BRANCH_VAL'"
fi

print_summary
