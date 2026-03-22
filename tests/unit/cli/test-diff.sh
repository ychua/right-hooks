#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

CLI="$SCRIPT_DIR/../../../bin/right-hooks.js"

echo "cli/diff"

# Setup: create a project with init first
cd "$TEST_TMPDIR"
git init -q
git commit --allow-empty -m "init" -q
echo '{}' > tsconfig.json
node "$CLI" init --yes >/dev/null 2>&1

# Test 1: diff exits 0 on up-to-date project
describe "diff exits 0 on up-to-date project"
node "$CLI" diff >"$TEST_TMPDIR/diff-out" 2>&1
assert_exit_code 0 $?

# Test 2: diff shows "up to date" when versions match
describe "diff reports already up to date"
assert_stdout_contains "up to date" "$TEST_TMPDIR/diff-out"

# Test 3: diff shows "would be updated" when hook content differs
describe "diff shows would-update when hook differs"
# Simulate an older installed version by changing version file and modifying a hook checksum
echo "0.0.1" > ".right-hooks/version"
# Modify a hook to differ from package
echo "# modified" >> ".right-hooks/hooks/judge.sh"
# Update checksum so it's not treated as "user modified"
node -e "
const fs = require('fs');
const crypto = require('crypto');
const content = fs.readFileSync('.right-hooks/hooks/judge.sh');
const hash = crypto.createHash('sha256').update(content).digest('hex');
const checksums = JSON.parse(fs.readFileSync('.right-hooks/.checksums', 'utf8'));
checksums['judge.sh'] = hash;
fs.writeFileSync('.right-hooks/.checksums', JSON.stringify(checksums, null, 2));
"
node "$CLI" diff >"$TEST_TMPDIR/diff-update" 2>&1
assert_stdout_contains "would be updated" "$TEST_TMPDIR/diff-update"

# Test 4: diff shows "preserved" when user modified a hook
describe "diff shows preserved when user modified hook"
# Modify hook WITHOUT updating checksum — simulates user edit
echo "# user edit" >> ".right-hooks/hooks/stop-check.sh"
node "$CLI" diff >"$TEST_TMPDIR/diff-preserved" 2>&1
assert_stdout_contains "preserved" "$TEST_TMPDIR/diff-preserved"

# Test 5: diff shows "new" when a hook doesn't exist locally
describe "diff shows new for missing hook"
rm -f ".right-hooks/hooks/session-start.sh"
node "$CLI" diff >"$TEST_TMPDIR/diff-new" 2>&1
assert_stdout_contains "new" "$TEST_TMPDIR/diff-new"

# Test 6: diff shows unchanged hooks
describe "diff shows unchanged hooks"
assert_stdout_contains "unchanged" "$TEST_TMPDIR/diff-update"

# Test 7: diff fails when not initialized
describe "diff fails when not initialized"
EMPTY="$TEST_TMPDIR/empty-proj"
mkdir -p "$EMPTY" && cd "$EMPTY"
node "$CLI" diff >"$TEST_TMPDIR/diff-fail" 2>&1
DIFF_EXIT=$?
if [ "$DIFF_EXIT" -ne 0 ]; then
  pass
else
  fail "Expected diff to fail in uninitialized project"
fi

print_summary
