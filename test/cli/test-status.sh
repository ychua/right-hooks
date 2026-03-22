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
describe "status shows active profile"
OUTPUT=$(node "$BIN" status 2>&1 || true)
if echo "$OUTPUT" | grep -qi "profile\|strict\|standard\|light"; then
  pass
else
  fail "Expected profile name in output: $OUTPUT"
fi

# --- status shows preset ---
describe "status shows active preset"
if echo "$OUTPUT" | grep -qi "preset\|typescript"; then
  pass
else
  fail "Expected preset in output: $OUTPUT"
fi

# --- status shows gates ---
describe "status shows gate status"
if echo "$OUTPUT" | grep -qi "gate\|ci\|dod\|learnings"; then
  pass
else
  fail "Expected gate info in output: $OUTPUT"
fi

# --- status exits 0 ---
describe "status exits 0 on valid project"
node "$BIN" status >/dev/null 2>&1
assert_exit_code 0 $?

print_summary
