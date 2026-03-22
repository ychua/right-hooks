#!/usr/bin/env bash
# Tests for: _preamble.sh helper functions
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

PREAMBLE="$(cd "$SCRIPT_DIR/../../../" && pwd)/hooks/_preamble.sh"

cd "$TEST_TMPDIR"
git init -q
mkdir -p .right-hooks/hooks .right-hooks/profiles
cp "$PREAMBLE" .right-hooks/hooks/_preamble.sh

# ── Test: rh_gate_value with multiple profiles ──
describe "rh_gate_value picks correct profile for branch type"
cat > .right-hooks/profiles/strict.json << 'PROF'
{"name":"strict","triggers":{"branchPrefix":["feat/"]},"gates":{"ci":true,"qa":true}}
PROF
cat > .right-hooks/profiles/light.json << 'PROF'
{"name":"light","triggers":{"branchPrefix":["docs/"]},"gates":{"ci":true,"qa":false}}
PROF

# docs/ branch should get light profile (qa=false)
GATE_VAL=$(source .right-hooks/hooks/_preamble.sh && rh_gate_value "docs" "qa")
if [ "$GATE_VAL" = "false" ]; then
  pass
else
  fail "Expected qa=false for docs/ (light profile), got $GATE_VAL"
fi

# feat/ branch should get strict profile (qa=true)
describe "rh_gate_value returns correct gate for feat/"
GATE_VAL=$(source .right-hooks/hooks/_preamble.sh && rh_gate_value "feat" "qa")
if [ "$GATE_VAL" = "true" ]; then
  pass
else
  fail "Expected qa=true for feat/ (strict profile), got $GATE_VAL"
fi

# ── Test: rh_debug only outputs when RH_DEBUG=1 ──
describe "rh_debug outputs nothing when RH_DEBUG unset"
STDERR_FILE="$TEST_TMPDIR/debug_test_stderr"
(source .right-hooks/hooks/_preamble.sh && rh_debug "test" "hello") 2>"$STDERR_FILE"
if [ -s "$STDERR_FILE" ]; then
  fail "Expected no output, got: $(cat "$STDERR_FILE")"
else
  pass
fi

describe "rh_debug outputs when RH_DEBUG=1"
STDERR_FILE="$TEST_TMPDIR/debug_test_stderr2"
(export RH_DEBUG=1; source .right-hooks/hooks/_preamble.sh; rh_debug "test" "hello") 2>"$STDERR_FILE"
if grep -q "DEBUG" "$STDERR_FILE" 2>/dev/null; then
  pass
else
  fail "Expected DEBUG output"
fi

# ── Test: rh_branch_type extracts prefix ──
describe "rh_branch_type extracts type from branch name"
git checkout -qb feat/test-branch 2>/dev/null || true
BRANCH_TYPE=$(source .right-hooks/hooks/_preamble.sh && rh_branch_type)
if [ "$BRANCH_TYPE" = "feat" ]; then
  pass
else
  fail "Expected 'feat', got '$BRANCH_TYPE'"
fi

print_summary
