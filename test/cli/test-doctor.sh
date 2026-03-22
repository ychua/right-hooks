#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

CLI="$SCRIPT_DIR/../../bin/right-hooks.js"

echo "cli/doctor"

# Setup: create a project with init first
cd "$TEST_TMPDIR"
git init -q
git commit --allow-empty -m "init" -q
echo '{}' > tsconfig.json
node "$CLI" init --yes >/dev/null 2>&1

# Test 1: Doctor exits 0 after clean init
describe "doctor exits 0 after clean init"
node "$CLI" doctor >"$TEST_TMPDIR/doctor-out" 2>&1
assert_exit_code 0 $?

# Test 2: Doctor output says all checks passed
describe "doctor reports all checks passed"
assert_stdout_contains "All checks passed" "$TEST_TMPDIR/doctor-out"

# Test 3: Doctor reports version
describe "doctor reports version"
assert_stdout_contains "Version:" "$TEST_TMPDIR/doctor-out"

# Test 4: Doctor reports active preset
describe "doctor reports active preset"
assert_stdout_contains "Active preset:" "$TEST_TMPDIR/doctor-out"

# Test 5: Doctor reports hooks present
describe "doctor reports all hooks present"
assert_stdout_contains "hooks present" "$TEST_TMPDIR/doctor-out"

# Test 6: Doctor fails when .right-hooks is missing
describe "doctor fails when not initialized"
EMPTY="$TEST_TMPDIR/empty-proj"
mkdir -p "$EMPTY" && cd "$EMPTY"
git init -q && git commit --allow-empty -m "init" -q
node "$CLI" doctor >"$TEST_TMPDIR/doctor-fail" 2>&1
DOCTOR_EXIT=$?
# Doctor exits 1 when not initialized
if [ "$DOCTOR_EXIT" -ne 0 ]; then
  pass
else
  fail "Expected doctor to fail in uninitialized project"
fi

print_summary
