#!/usr/bin/env bash
# Tests for: right-hooks override
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

# --- override requires gate ---
describe "override without gate shows usage"
OUTPUT=$(node "$BIN" override 2>&1 || true)
EXIT=$?
if echo "$OUTPUT" | grep -qi "gate\|usage\|reason"; then
  pass
else
  fail "Expected usage/gate info: $OUTPUT"
fi

# --- override requires reason ---
describe "override without reason fails"
OUTPUT=$(node "$BIN" override --gate=qa 2>&1 || true)
EXIT=$?
if echo "$OUTPUT" | grep -qi "reason"; then
  pass
else
  fail "Expected reason required message: $OUTPUT"
fi

# --- valid override creates file ---
describe "override with gate and reason succeeds"
node "$BIN" override --gate=qa --reason="Manual testing completed" >/dev/null 2>&1 && EXIT=0 || EXIT=$?
if [ "$EXIT" -eq 0 ]; then
  pass
else
  fail "Expected exit 0, got $EXIT"
fi

# --- override is recorded ---
describe "override is recorded in overrides directory"
if ls .right-hooks/.overrides/*.json >/dev/null 2>&1; then
  if grep -rq "qa" .right-hooks/.overrides/; then
    pass
  else
    fail "Expected qa override in .overrides/"
  fi
else
  fail ".overrides/ directory empty or not created"
fi

# --- overrides list works ---
describe "overrides list shows active overrides"
OUTPUT=$(node "$BIN" overrides 2>&1 || true)
if echo "$OUTPUT" | grep -qi "qa"; then
  pass
else
  fail "Expected qa in overrides list: $OUTPUT"
fi

print_summary
