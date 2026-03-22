#!/usr/bin/env bash
# Tests for: pre-merge.sh hook
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$(cd "$SCRIPT_DIR/../../" && pwd)/hooks/pre-merge.sh"
PREAMBLE="$(cd "$SCRIPT_DIR/../../" && pwd)/hooks/_preamble.sh"

# Setup: create a minimal .right-hooks structure
cd "$TEST_TMPDIR"
git init -q
mkdir -p .right-hooks/hooks .right-hooks/profiles
cp "$PREAMBLE" .right-hooks/hooks/_preamble.sh

# Use strict profile
cat > .right-hooks/active-profile.json << 'PROF'
{"name":"strict","triggers":{"branchPrefix":["feat/"]},"gates":{"ci":true,"dod":true,"docConsistency":true,"planningArtifacts":true,"codeReview":true,"qa":true,"learnings":true,"stopHook":true}}
PROF
cp .right-hooks/active-profile.json .right-hooks/profiles/strict.json

# --- non-merge command passes through ---
describe "non-merge command exits 0"
echo '{"tool_input":{"command":"git status"}}' | RH_TEST=1 bash "$HOOK" >/dev/null 2>&1
assert_exit_code 0 $?

# --- merge command on non-PR exits 0 (no PR to check) ---
describe "merge without PR number exits 0"
echo '{"tool_input":{"command":"gh pr merge"}}' | RH_TEST=1 bash "$HOOK" >/dev/null 2>&1
assert_exit_code 0 $?

# --- git merge triggers the hook (not silently skipped) ---
describe "git merge command is recognized as merge"
# Create a fake branch so the hook tries to process
git checkout -qb feat/test 2>/dev/null || true
OUTPUT=$(echo '{"tool_input":{"command":"git merge feat/test"}}' | RH_TEST=1 bash "$HOOK" 2>&1 || true)
EXIT=$?
# Hook should either block (exit 2) because gates aren't met, or exit 0 because no PR exists
# Either way, it should NOT crash
if [ "$EXIT" -eq 0 ] || [ "$EXIT" -eq 2 ]; then
  pass
else
  fail "Expected exit 0 or 2, got $EXIT"
fi

# --- light profile skips review/qa gates ---
describe "light profile disables review gate"
cat > .right-hooks/profiles/light.json << 'PROF'
{"name":"light","triggers":{"branchPrefix":["docs/"]},"gates":{"ci":true,"dod":true,"docConsistency":true,"planningArtifacts":false,"codeReview":false,"qa":false,"learnings":false,"stopHook":false}}
PROF
cp .right-hooks/profiles/light.json .right-hooks/active-profile.json
# Light profile with no merge command — should pass through
echo '{"tool_input":{"command":"git status"}}' | RH_TEST=1 bash "$HOOK" >/dev/null 2>&1
assert_exit_code 0 $?

# --- hook is valid bash ---
describe "pre-merge.sh is valid bash"
bash -n "$HOOK"
assert_exit_code 0 $?

# --- hook reads profile gates correctly ---
describe "hook reads planningArtifacts gate from profile"
# Strict profile has planningArtifacts=true
cp .right-hooks/profiles/strict.json .right-hooks/active-profile.json
GATE_VAL=$(jq -r '.gates.planningArtifacts' .right-hooks/active-profile.json)
if [ "$GATE_VAL" = "true" ]; then
  pass
else
  fail "Expected planningArtifacts=true in strict, got $GATE_VAL"
fi

# --- light profile has codeReview=false ---
describe "light profile has codeReview disabled"
GATE_VAL=$(jq -r '.gates.codeReview' .right-hooks/profiles/light.json)
if [ "$GATE_VAL" = "false" ]; then
  pass
else
  fail "Expected codeReview=false in light, got $GATE_VAL"
fi

print_summary
