#!/usr/bin/env bash
# Tests for: ANSI color support in _preamble.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

PREAMBLE="$(cd "$SCRIPT_DIR/../../../" && pwd)/hooks/_preamble.sh"

cd "$TEST_TMPDIR"
git init -q
mkdir -p .right-hooks/hooks .right-hooks/profiles .right-hooks/.stats
cp "$PREAMBLE" .right-hooks/hooks/_preamble.sh

# ── Test: _RH_COLOR_FORCE enables ANSI codes ──
describe "rh_pass outputs green ANSI when _RH_COLOR_FORCE=1"
OUTPUT=$(RH_TEST=1 _RH_COLOR_FORCE=1 bash -c "source '.right-hooks/hooks/_preamble.sh'; rh_pass 'test' 'ok'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\[32m'; then
  pass
else
  fail "Expected green ANSI code (\\033[32m) in output"
fi

# ── Test: NO_COLOR suppresses all ANSI ──
describe "rh_pass suppresses ANSI when NO_COLOR=1"
OUTPUT=$(RH_TEST=1 NO_COLOR=1 bash -c "source '.right-hooks/hooks/_preamble.sh'; rh_pass 'test' 'ok'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\['; then
  fail "Found ANSI escape in output despite NO_COLOR=1"
else
  pass
fi

# ── Test: rh_block outputs red ANSI when forced ──
describe "rh_block outputs red ANSI when _RH_COLOR_FORCE=1"
OUTPUT=$(RH_TEST=1 _RH_COLOR_FORCE=1 bash -c "source '.right-hooks/hooks/_preamble.sh'; rh_block 'test' 'blocked' 'ci'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\[31m'; then
  pass
else
  fail "Expected red ANSI code (\\033[31m) in output"
fi

# ── Test: rh_block suppresses ANSI when NO_COLOR ──
describe "rh_block suppresses ANSI when NO_COLOR=1"
OUTPUT=$(RH_TEST=1 NO_COLOR=1 bash -c "source '.right-hooks/hooks/_preamble.sh'; rh_block 'test' 'blocked' 'ci'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\['; then
  fail "Found ANSI escape in output despite NO_COLOR=1"
else
  pass
fi

# ── Test: rh_info outputs blue ANSI when forced ──
describe "rh_info outputs blue ANSI when _RH_COLOR_FORCE=1"
OUTPUT=$(RH_TEST=1 _RH_COLOR_FORCE=1 bash -c "source '.right-hooks/hooks/_preamble.sh'; rh_info 'test' 'info'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\[34m'; then
  pass
else
  fail "Expected blue ANSI code (\\033[34m) in output"
fi

# ── Test: rh_debug outputs dim ANSI when forced ──
describe "rh_debug outputs dim ANSI when _RH_COLOR_FORCE=1 and RH_DEBUG=1"
OUTPUT=$(RH_TEST=1 RH_DEBUG=1 _RH_COLOR_FORCE=1 bash -c "source '.right-hooks/hooks/_preamble.sh'; rh_debug 'test' 'debug'" 2>&1)
if echo "$OUTPUT" | grep -q $'\033\[2m'; then
  pass
else
  fail "Expected dim ANSI code (\\033[2m) in output"
fi

# ── Test: rh_block shows explain hint with gate name ──
describe "rh_block shows explain hint with gate name"
OUTPUT=$(RH_TEST=1 NO_COLOR=1 bash -c "source '.right-hooks/hooks/_preamble.sh'; rh_block 'test' 'blocked' 'ci'" 2>&1)
if echo "$OUTPUT" | grep -q "npx right-hooks explain ci"; then
  pass
else
  fail "Expected explain hint with gate name 'ci'"
fi

# ── Test: rh_block shows generic explain hint without gate name ──
describe "rh_block shows generic explain hint without gate name"
OUTPUT=$(RH_TEST=1 NO_COLOR=1 bash -c "source '.right-hooks/hooks/_preamble.sh'; rh_block 'test' 'blocked'" 2>&1)
if echo "$OUTPUT" | grep -q "npx right-hooks explain"; then
  pass
else
  fail "Expected generic explain hint"
fi

# ── Test: rh_block_end shows explain hint ──
describe "rh_block_end shows explain hint"
OUTPUT=$(RH_TEST=1 NO_COLOR=1 bash -c "source '.right-hooks/hooks/_preamble.sh'; rh_block_start 'test'; rh_block_item 'item1'; rh_block_end" 2>&1)
if echo "$OUTPUT" | grep -q "npx right-hooks explain"; then
  pass
else
  fail "Expected explain hint from rh_block_end"
fi

# ── Test: _rh_explain_hint with gate produces gate-specific message ──
describe "_rh_explain_hint with gate produces gate-specific message"
OUTPUT=$(RH_TEST=1 NO_COLOR=1 bash -c "source '.right-hooks/hooks/_preamble.sh'; _rh_explain_hint 'planningArtifacts'" 2>&1)
if echo "$OUTPUT" | grep -q "npx right-hooks explain planningArtifacts"; then
  pass
else
  fail "Expected gate-specific explain hint"
fi

# ── Test: _rh_explain_hint without gate produces generic message ──
describe "_rh_explain_hint without gate produces generic message"
OUTPUT=$(RH_TEST=1 NO_COLOR=1 bash -c "source '.right-hooks/hooks/_preamble.sh'; _rh_explain_hint" 2>&1)
if echo "$OUTPUT" | grep -q "npx right-hooks explain' to see all gates"; then
  pass
else
  fail "Expected generic explain hint"
fi

print_summary
