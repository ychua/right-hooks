#!/usr/bin/env bash
# Tests for: npx right-hooks stats CLI command
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

CLI="$(cd "$SCRIPT_DIR/../../../" && pwd)/bin/right-hooks.js"

cd "$TEST_TMPDIR"
mkdir -p .right-hooks/.stats

# --- no events file ---
describe "stats with no events file shows empty message"
rm -f .right-hooks/.stats/events.jsonl
OUTPUT=$(node "$CLI" stats 2>&1 || true)
if echo "$OUTPUT" | grep -qi "no events"; then
  pass
else
  fail "Expected 'no events' message, got: $OUTPUT"
fi

# --- empty events file ---
describe "stats with empty events file shows empty message"
touch .right-hooks/.stats/events.jsonl
OUTPUT=$(node "$CLI" stats 2>&1 || true)
if echo "$OUTPUT" | grep -qi "no events"; then
  pass
else
  fail "Expected 'no events' message, got: $OUTPUT"
fi

# --- valid events produce gate table ---
describe "stats shows gate table with pass/block counts"
cat > .right-hooks/.stats/events.jsonl << 'EVENTS'
{"ts":"2026-03-23T14:00:00Z","hook":"pre-merge","gate":"ci","result":"pass","branch":"feat/test","pr":1}
{"ts":"2026-03-23T14:00:01Z","hook":"pre-merge","gate":"ci","result":"pass","branch":"feat/test","pr":1}
{"ts":"2026-03-23T14:00:02Z","hook":"pre-merge","gate":"ci","result":"block","branch":"feat/test","pr":1}
{"ts":"2026-03-23T14:00:03Z","hook":"pre-merge","gate":"codeReview","result":"pass","branch":"feat/test","pr":1}
{"ts":"2026-03-23T14:00:04Z","hook":"pre-merge","gate":"codeReview","result":"block","branch":"feat/test","pr":1}
{"ts":"2026-03-23T14:00:05Z","hook":"pre-merge","gate":"codeReview","result":"block","branch":"feat/test","pr":1}
EVENTS
OUTPUT=$(node "$CLI" stats 2>&1 || true)
if echo "$OUTPUT" | grep -q "ci" && echo "$OUTPUT" | grep -q "codeReview"; then
  pass
else
  fail "Expected gate names in output, got: $OUTPUT"
fi

# --- block percentage is calculated ---
describe "stats shows correct block percentage"
OUTPUT=$(node "$CLI" stats 2>&1 || true)
# codeReview: 1 pass, 2 block = 66.7%
if echo "$OUTPUT" | grep -q "66.7"; then
  pass
else
  fail "Expected 66.7% block rate for codeReview, got: $OUTPUT"
fi

# --- stop events produce human involvement table ---
describe "stats shows human involvement table"
cat >> .right-hooks/.stats/events.jsonl << 'EVENTS'
{"ts":"2026-03-23T14:01:00Z","hook":"stop-check","gate":"stop","result":"pass","branch":"feat/test","pr":1,"stop_reason":"pipeline_complete"}
{"ts":"2026-03-23T14:01:01Z","hook":"stop-check","gate":"stop","result":"pass","branch":"feat/test","pr":1,"stop_reason":"pipeline_complete"}
{"ts":"2026-03-23T14:01:02Z","hook":"stop-check","gate":"stop","result":"pass","branch":"feat/test","stop_reason":"no_pr"}
EVENTS
OUTPUT=$(node "$CLI" stats 2>&1 || true)
if echo "$OUTPUT" | grep -q "pipeline_complete" && echo "$OUTPUT" | grep -q "Human Involvement"; then
  pass
else
  fail "Expected Human Involvement section with pipeline_complete, got: $OUTPUT"
fi

# --- stop block events excluded from human involvement ---
describe "stop block events not in human involvement table"
cat >> .right-hooks/.stats/events.jsonl << 'EVENTS'
{"ts":"2026-03-23T14:02:00Z","hook":"stop-check","gate":"stop","result":"block","branch":"feat/test","pr":1,"stop_reason":"missing_review"}
EVENTS
OUTPUT=$(node "$CLI" stats 2>&1 || true)
# missing_review is a block event — should NOT appear in Human Involvement
if echo "$OUTPUT" | grep "Human Involvement" -A 20 | grep -q "missing_review"; then
  fail "Block stop event should not appear in Human Involvement"
else
  pass
fi

# --- malformed lines are skipped ---
describe "stats skips malformed JSON lines"
echo "this is not json" >> .right-hooks/.stats/events.jsonl
OUTPUT=$(node "$CLI" stats 2>&1 || true)
# Should still show data from valid lines, not crash
if echo "$OUTPUT" | grep -q "ci"; then
  pass
else
  fail "Expected stats output despite malformed line, got: $OUTPUT"
fi

# --- avg stops per PR ---
describe "stats shows avg stops per PR"
OUTPUT=$(node "$CLI" stats 2>&1 || true)
if echo "$OUTPUT" | grep -q "Avg stops per PR"; then
  pass
else
  fail "Expected 'Avg stops per PR' in output, got: $OUTPUT"
fi

# --- since date ---
describe "stats shows since date from earliest event"
OUTPUT=$(node "$CLI" stats 2>&1 || true)
if echo "$OUTPUT" | grep -q "2026-03-23"; then
  pass
else
  fail "Expected since date 2026-03-23, got: $OUTPUT"
fi

# --- total events count ---
describe "stats shows total events count"
OUTPUT=$(node "$CLI" stats 2>&1 || true)
if echo "$OUTPUT" | grep -q "Total events:"; then
  pass
else
  fail "Expected 'Total events:' in output, got: $OUTPUT"
fi

print_summary
