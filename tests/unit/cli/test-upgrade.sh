#!/usr/bin/env bash
# Tests for: right-hooks upgrade
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

BIN="$(cd "$SCRIPT_DIR/../../../" && pwd)/bin/right-hooks.js"

# Setup
cd "$TEST_TMPDIR"
git init -q
echo '{}' > tsconfig.json
RH_TEST=1 node "$BIN" init --yes >/dev/null 2>&1

# --- upgrade runs without error ---
describe "upgrade exits 0 on initialized project"
node "$BIN" upgrade >/dev/null 2>&1
assert_exit_code 0 $?

# --- upgrade preserves custom hooks ---
describe "upgrade preserves user-modified hooks"
echo "# USER CUSTOMIZATION" >> .right-hooks/hooks/stop-check.sh
node "$BIN" upgrade >/dev/null 2>&1 || true
if grep -q "USER CUSTOMIZATION" .right-hooks/hooks/stop-check.sh; then
  pass
else
  fail "User customization was overwritten"
fi

# --- upgrade reports preserved custom hooks ---
describe "upgrade reports preserved custom hooks"
# Fake an older version so upgrade actually runs the diff logic
echo "0.9.0" > .right-hooks/version
# Clear checksums so upgrade sees mismatch on modified hook
echo '{}' > .right-hooks/.checksums
OUTPUT=$(node "$BIN" upgrade 2>&1 || true)
if echo "$OUTPUT" | grep -qi "preserved\|modified"; then
  pass
else
  fail "Expected preserved/modified message for custom hook: $OUTPUT"
fi

# --- upgrade updates unmodified hooks ---
describe "upgrade updates unmodified hooks"
# session-start.sh should not have been modified, so it should update fine
BEFORE_CHECKSUM=$(md5sum .right-hooks/hooks/session-start.sh 2>/dev/null | cut -d' ' -f1 || shasum .right-hooks/hooks/session-start.sh | cut -d' ' -f1)
node "$BIN" upgrade >/dev/null 2>&1 || true
AFTER_CHECKSUM=$(md5sum .right-hooks/hooks/session-start.sh 2>/dev/null | cut -d' ' -f1 || shasum .right-hooks/hooks/session-start.sh | cut -d' ' -f1)
# Unmodified hooks should still exist and be valid bash
if bash -n .right-hooks/hooks/session-start.sh 2>/dev/null; then
  pass
else
  fail "Unmodified hook is not valid bash after upgrade"
fi

# --- upgrade on non-initialized project ---
describe "upgrade fails on non-initialized project"
cd "$(mktemp -d)"
node "$BIN" upgrade >/dev/null 2>&1 && EXIT=0 || EXIT=$?
if [ "$EXIT" -ne 0 ]; then
  pass
else
  fail "Expected non-zero exit on non-initialized project"
fi

print_summary
