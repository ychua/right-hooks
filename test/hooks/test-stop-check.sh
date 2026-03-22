#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../hooks/stop-check.sh"

echo "stop-check"

# Setup: create a git repo
cd "$TEST_TMPDIR"
git init -q
git commit --allow-empty -m "init" -q

# Test 1: Allow on non-code-review branches (docs/)
describe "allows stop on docs/ branch"
git checkout -q -b docs/update
run_hook "$HOOK" '{}'
assert_exit_code 0 "$LAST_EXIT"

# Test 2: Allow on chore/ branch
describe "allows stop on chore/ branch"
git checkout -q -b chore/cleanup
run_hook "$HOOK" '{}'
assert_exit_code 0 "$LAST_EXIT"

# Test 3: Allow on feat/ when no PR exists (rh_pr_number returns empty)
describe "allows stop on feat/ with no open PR"
git checkout -q -b feat/test-stop
# No PR exists in test env, so rh_pr_number returns empty → exit 0
run_hook "$HOOK" '{}'
assert_exit_code 0 "$LAST_EXIT"

# Test 4: Allow on master (not in code-review types)
describe "allows stop on master"
git checkout -q -b master 2>/dev/null || git checkout -q master
run_hook "$HOOK" '{}'
assert_exit_code 0 "$LAST_EXIT"

print_summary
