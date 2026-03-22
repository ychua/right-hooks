#!/usr/bin/env bash
# Tests for: right-hooks preset
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

# --- switch to python ---
describe "preset switches to python"
OUTPUT=$(node "$BIN" preset python 2>&1)
if echo "$OUTPUT" | grep -qF "python"; then
  pass
else
  fail "Expected python confirmation: $OUTPUT"
fi

# --- active-preset.json updated ---
describe "active-preset.json reflects python"
assert_file_contains .right-hooks/active-preset.json "python"

# --- switch to go ---
describe "preset switches to go"
OUTPUT=$(node "$BIN" preset go 2>&1)
if echo "$OUTPUT" | grep -qF "go"; then
  pass
else
  fail "Expected go confirmation: $OUTPUT"
fi

# --- invalid preset fails ---
describe "invalid preset fails"
node "$BIN" preset nonexistent >/dev/null 2>&1 && EXIT=0 || EXIT=$?
if [ "$EXIT" -ne 0 ]; then
  pass
else
  fail "Expected non-zero exit for invalid preset"
fi

# --- no arg shows usage ---
describe "preset without arg shows usage"
OUTPUT=$(node "$BIN" preset 2>&1 || true)
if echo "$OUTPUT" | grep -qi "usage\|available"; then
  pass
else
  fail "Expected usage message: $OUTPUT"
fi

print_summary
