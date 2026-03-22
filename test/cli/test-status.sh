#!/usr/bin/env bash
# Tests for: right-hooks status
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

BIN="$(cd "$SCRIPT_DIR/../../" && pwd)/bin/right-hooks.js"

# Setup: init a project in temp dir
cd "$TEST_TMPDIR"
git init -q
echo '{}' > tsconfig.json
RH_TEST=1 node "$BIN" init --yes >/dev/null 2>&1

# --- status shows profile name ---
describe "status shows Profile: line"
OUTPUT=$(node "$BIN" status 2>&1 || true)
if echo "$OUTPUT" | grep -q "^Profile:"; then
  pass
else
  fail "Expected 'Profile:' line in output: $OUTPUT"
fi

# --- status shows preset ---
describe "status shows Preset: line"
if echo "$OUTPUT" | grep -q "^Preset:"; then
  pass
else
  fail "Expected 'Preset:' line in output: $OUTPUT"
fi

# --- status shows gates ---
describe "status shows Gates section with ci"
if echo "$OUTPUT" | grep -q "✓ ci"; then
  pass
else
  fail "Expected '✓ ci' in gate list: $OUTPUT"
fi

# --- status shows learnings gate ---
describe "status shows learnings gate"
if echo "$OUTPUT" | grep -q "learnings"; then
  pass
else
  fail "Expected 'learnings' in gate list: $OUTPUT"
fi

# --- status exits 0 ---
describe "status exits 0 on valid project"
node "$BIN" status >/dev/null 2>&1
assert_exit_code 0 $?

# --- status fails on non-initialized project ---
describe "status fails on non-initialized project"
cd "$(mktemp -d)"
node "$BIN" status >/dev/null 2>&1 && EXIT=0 || EXIT=$?
if [ "$EXIT" -ne 0 ]; then
  pass
else
  fail "Expected non-zero exit on non-initialized project"
fi

print_summary
