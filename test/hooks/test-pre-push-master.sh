#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../hooks/pre-push-master.sh"

# Setup: create a minimal git repo so rh_branch works
cd "$TEST_TMPDIR"
git init -q
git commit --allow-empty -m "init" -q

echo "pre-push-master"

# Test 1: Block push to master
describe "blocks push to master"
git checkout -q -b master 2>/dev/null || git checkout -q master
run_hook "$HOOK" '{"tool_input":{"command":"git push origin master"}}'
assert_exit_code 2 "$LAST_EXIT"

# Test 2: Block push to main
describe "blocks push to main"
git checkout -q -b main 2>/dev/null
run_hook "$HOOK" '{"tool_input":{"command":"git push origin main"}}'
assert_exit_code 2 "$LAST_EXIT"

# Test 3: Stderr contains helpful message
describe "stderr tells user to create branch"
assert_stderr_contains "direct push to" "$LAST_STDERR"

# Test 4: Allow push to feature branch
describe "allows push to feature branch"
git checkout -q -b feat/test
run_hook "$HOOK" '{"tool_input":{"command":"git push origin feat/test"}}'
assert_exit_code 0 "$LAST_EXIT"

# Test 5: Allow non-push commands
describe "allows non-push commands"
git checkout -q master
run_hook "$HOOK" '{"tool_input":{"command":"git status"}}'
assert_exit_code 0 "$LAST_EXIT"

print_summary
