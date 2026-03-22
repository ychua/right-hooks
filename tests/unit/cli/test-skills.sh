#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

CLI="$SCRIPT_DIR/../../../bin/right-hooks.js"

echo "cli/skills"

# Setup: create a project with init first
cd "$TEST_TMPDIR"
git init -q -b main
git config user.email "test@test.com"
git config user.name "Test"
git commit --allow-empty -m "init" -q
echo '{}' > tsconfig.json
node "$CLI" init --yes >/dev/null 2>&1

# Test 1: skills shows configured skills after init
describe "skills shows configured skills"
node "$CLI" skills >"$TEST_TMPDIR/skills-out" 2>&1
assert_stdout_contains "codeReview" "$TEST_TMPDIR/skills-out"

# Test 2: skills shows gate names
describe "skills shows qa gate"
assert_stdout_contains "qa" "$TEST_TMPDIR/skills-out"

# Test 3: skills shows docConsistency gate
describe "skills shows docConsistency gate"
assert_stdout_contains "docConsistency" "$TEST_TMPDIR/skills-out"

# Test 4: skills set updates codeReview skill
describe "skills set updates codeReview"
node "$CLI" skills set codeReview /my-review >"$TEST_TMPDIR/set-out" 2>&1
assert_stdout_contains "codeReview skill set to" "$TEST_TMPDIR/set-out"

# Test 5: skills set wrote to skills.json
describe "skills set wrote to skills.json"
assert_file_contains ".right-hooks/skills.json" "/my-review"

# Test 6: skills set infers gstack provider from / prefix
describe "skills set infers gstack provider"
assert_file_contains ".right-hooks/skills.json" '"gstack"'

# Test 7: skills set infers superpowers provider
describe "skills set infers superpowers provider"
node "$CLI" skills set qa superpowers:my-qa >/dev/null 2>&1
assert_file_contains ".right-hooks/skills.json" '"superpowers"'

# Test 8: skills set rejects invalid gate
describe "skills set rejects invalid gate"
node "$CLI" skills set invalidGate /foo >"$TEST_TMPDIR/invalid-out" 2>&1
INVALID_EXIT=$?
if [ "$INVALID_EXIT" -ne 0 ]; then
  pass
else
  fail "Expected non-zero exit for invalid gate"
fi

# Test 9: skills set with no args shows usage
describe "skills set with no args shows usage"
node "$CLI" skills set >"$TEST_TMPDIR/usage-out" 2>&1
USAGE_EXIT=$?
if [ "$USAGE_EXIT" -ne 0 ]; then
  pass
else
  fail "Expected non-zero exit for missing args"
fi

# Test 10: skills works on uninitialized project
describe "skills warns on uninitialized project"
EMPTY="$TEST_TMPDIR/empty-proj"
mkdir -p "$EMPTY" && cd "$EMPTY"
node "$CLI" skills >"$TEST_TMPDIR/no-skills" 2>&1
assert_stdout_contains "No skills.json" "$TEST_TMPDIR/no-skills"

print_summary
