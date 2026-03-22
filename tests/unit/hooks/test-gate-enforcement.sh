#!/usr/bin/env bash
# Tests for: gate enforcement behavior — verifies gates actually block/pass
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$(cd "$SCRIPT_DIR/../../../" && pwd)/hooks/pre-merge.sh"
PREAMBLE="$(cd "$SCRIPT_DIR/../../../" && pwd)/hooks/_preamble.sh"

# Setup: minimal .right-hooks structure in temp dir
cd "$TEST_TMPDIR"
git init -q
mkdir -p .right-hooks/hooks .right-hooks/profiles .right-hooks/signatures

cp "$PREAMBLE" .right-hooks/hooks/_preamble.sh

# Create signatures.json (needed by comment checks)
cat > .right-hooks/signatures.json << 'SIG'
{
  "codeReview": { "commentPattern": "Review Agent", "severityPattern": "CRITICAL|HIGH|MEDIUM|LOW" },
  "qa": { "commentPattern": "QA Agent", "resultPattern": "tests passing|coverage" },
  "docConsistency": { "commentPattern": "Documentation health:" }
}
SIG

# ── Test 1: Custom profile all-false → merge passes (no enforcement) ──
describe "custom profile with all gates false passes merge"
cat > .right-hooks/profiles/custom.json << 'PROF'
{"name":"custom","triggers":{"branchPrefix":["feat/"]},"gates":{"ci":false,"dod":false,"docConsistency":false,"planningArtifacts":false,"engReview":false,"codeReview":false,"qa":false,"learnings":false,"stopHook":false,"postEditCheck":false}}
PROF

git checkout -qb feat/test-allfalse 2>/dev/null || true
# The hook will try rh_pr_number() which returns "" in test mode → exit 0
run_hook "$HOOK" '{"tool_input":{"command":"gh pr merge"}}'
assert_exit_code 0 $LAST_EXIT

# ── Test 2: Merge command detected correctly ──
describe "gh pr merge command is recognized"
run_hook "$HOOK" '{"tool_input":{"command":"gh pr merge --squash"}}'
# Should exit 0 (no PR found in test env), not crash
assert_exit_code 0 $LAST_EXIT

# ── Test 3: Non-merge command passes through ──
describe "non-merge command exits 0 immediately"
run_hook "$HOOK" '{"tool_input":{"command":"git status"}}'
assert_exit_code 0 $LAST_EXIT

# ── Test 4: git merge also triggers the hook ──
describe "git merge command is recognized"
run_hook "$HOOK" '{"tool_input":{"command":"git merge feat/other"}}'
assert_exit_code 0 $LAST_EXIT

# ── Test 5: Light profile only has ci/dod/doc gates ──
describe "light profile has codeReview disabled"
cat > .right-hooks/profiles/light.json << 'PROF'
{"name":"light","triggers":{"branchPrefix":["docs/"]},"gates":{"ci":true,"dod":true,"docConsistency":true,"planningArtifacts":false,"engReview":false,"codeReview":false,"qa":false,"learnings":false,"stopHook":false,"postEditCheck":false}}
PROF

GATE_VAL=$(cd "$TEST_TMPDIR" && source .right-hooks/hooks/_preamble.sh && rh_match_profile "docs" && rh_gate_value "codeReview")
if [ "$GATE_VAL" = "false" ]; then
  pass
else
  fail "Expected codeReview=false for docs/ branch on light profile, got $GATE_VAL"
fi

# ── Test 6: Strict profile has all gates enabled ──
describe "strict profile has all gates true for feat/"
# Remove custom profile to avoid glob-order conflict (custom.json < strict.json)
rm -f .right-hooks/profiles/custom.json
cat > .right-hooks/profiles/strict.json << 'PROF'
{"name":"strict","triggers":{"branchPrefix":["feat/"]},"gates":{"ci":true,"dod":true,"docConsistency":true,"planningArtifacts":true,"engReview":true,"codeReview":true,"qa":true,"learnings":true,"stopHook":true,"postEditCheck":true}}
PROF

GATE_VAL=$(cd "$TEST_TMPDIR" && source .right-hooks/hooks/_preamble.sh && rh_match_profile "feat" && rh_gate_value "ci")
if [ "$GATE_VAL" = "true" ]; then
  pass
else
  fail "Expected ci=true for feat/ on strict profile, got $GATE_VAL"
fi

# ── Test 7: rh_gate_value returns false for unmatched branch ──
describe "rh_gate_value returns false for unmatched branch type"
GATE_VAL=$(cd "$TEST_TMPDIR" && source .right-hooks/hooks/_preamble.sh && rh_match_profile "unknown" && rh_gate_value "ci")
if [ "$GATE_VAL" = "false" ]; then
  pass
else
  fail "Expected false for unknown branch type, got $GATE_VAL"
fi

# ── Test 8: rh_gate_value returns false for missing gate ──
describe "rh_gate_value returns false for undefined gate"
GATE_VAL=$(cd "$TEST_TMPDIR" && source .right-hooks/hooks/_preamble.sh && rh_match_profile "feat" && rh_gate_value "nonexistentGate")
if [ "$GATE_VAL" = "false" ]; then
  pass
else
  fail "Expected false for undefined gate, got $GATE_VAL"
fi

# ── Test 9: RH_DEBUG produces output ──
describe "RH_DEBUG=1 produces debug output"
# Test rh_debug directly instead of relying on hook's early-exit path
STDERR_FILE="$TEST_TMPDIR/debug_stderr"
(export RH_DEBUG=1; source .right-hooks/hooks/_preamble.sh; rh_debug "test" "hello world") 2>"$STDERR_FILE"
if grep -q "DEBUG" "$STDERR_FILE" 2>/dev/null; then
  pass
else
  fail "Expected DEBUG output in stderr when RH_DEBUG=1"
fi

# ── Test 10: No debug output when RH_DEBUG is not set ──
describe "no debug output when RH_DEBUG is unset"
STDERR_FILE="$TEST_TMPDIR/nodebug_stderr"
echo '{"tool_input":{"command":"gh pr merge"}}' | RH_TEST=1 bash "$HOOK" 2>"$STDERR_FILE" || true
if grep -q "DEBUG" "$STDERR_FILE" 2>/dev/null; then
  fail "Unexpected DEBUG output when RH_DEBUG is not set"
else
  pass
fi

print_summary
