#!/usr/bin/env bash
# Tests for: right-hooks profile
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

BIN="$(cd "$SCRIPT_DIR/../../" && pwd)/bin/right-hooks.js"

# Setup
cd "$TEST_TMPDIR"
git init -q
echo '{}' > tsconfig.json
RH_TEST=1 node "$BIN" init --yes >/dev/null 2>&1

# --- switch to light ---
describe "profile switches to light"
OUTPUT=$(node "$BIN" profile light 2>&1)
if echo "$OUTPUT" | grep -qF "light"; then
  pass
else
  fail "Expected light confirmation: $OUTPUT"
fi

# --- active-profile.json updated ---
describe "active-profile.json reflects light"
assert_file_contains .right-hooks/active-profile.json '"name": "light"'

# --- light profile has fewer gates ---
describe "light profile disables learnings"
if jq -e '.gates.learnings == false' .right-hooks/active-profile.json >/dev/null 2>&1; then
  pass
else
  fail "Expected learnings=false in light profile"
fi

# --- switch to strict ---
describe "profile switches to strict"
node "$BIN" profile strict >/dev/null 2>&1
assert_file_contains .right-hooks/active-profile.json '"name": "strict"'

# --- strict has all gates ---
describe "strict profile enables all gates"
DISABLED=$(jq '[.gates | to_entries[] | select(.value == false)] | length' .right-hooks/active-profile.json 2>/dev/null)
if [ "$DISABLED" = "0" ]; then
  pass
else
  fail "Expected all gates enabled, $DISABLED disabled"
fi

# --- switch to custom ---
describe "profile switches to custom"
OUTPUT=$(node "$BIN" profile custom 2>&1)
if echo "$OUTPUT" | grep -qF "custom"; then
  pass
else
  fail "Expected custom confirmation: $OUTPUT"
fi

# --- invalid profile fails ---
describe "invalid profile fails"
node "$BIN" profile nonexistent >/dev/null 2>&1 && EXIT=0 || EXIT=$?
if [ "$EXIT" -ne 0 ]; then
  pass
else
  fail "Expected non-zero exit for invalid profile"
fi

# --- no arg shows usage ---
describe "profile without arg shows usage"
OUTPUT=$(node "$BIN" profile 2>&1 || true)
if echo "$OUTPUT" | grep -qi "usage\|available"; then
  pass
else
  fail "Expected usage message: $OUTPUT"
fi

print_summary
