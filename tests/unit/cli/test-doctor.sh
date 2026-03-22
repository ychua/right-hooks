#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

CLI="$SCRIPT_DIR/../../../bin/right-hooks.js"

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

# ── doctor --fix tests ──

# Setup: go back to initialized project
cd "$TEST_TMPDIR"

# Test 7: --fix restores a missing hook
describe "doctor --fix restores missing hook"
rm -f ".right-hooks/hooks/judge.sh"
node "$CLI" doctor --fix >"$TEST_TMPDIR/fix-out" 2>&1
assert_file_exists ".right-hooks/hooks/judge.sh"

# Test 8: --fix reports what it fixed
describe "doctor --fix reports restoration"
assert_stdout_contains "Restored missing hook" "$TEST_TMPDIR/fix-out"

# Test 9: --fix repairs permissions
describe "doctor --fix repairs non-executable hook"
chmod 644 ".right-hooks/hooks/stop-check.sh"
node "$CLI" doctor --fix >"$TEST_TMPDIR/fix-perm" 2>&1
# Check the file is now executable
if [ -x ".right-hooks/hooks/stop-check.sh" ]; then
  pass
else
  fail "Expected stop-check.sh to be executable after --fix"
fi

# Test 10: --fix regenerates missing checksums
describe "doctor --fix regenerates missing checksums"
rm -f ".right-hooks/.checksums"
node "$CLI" doctor --fix >"$TEST_TMPDIR/fix-checksum" 2>&1
assert_file_exists ".right-hooks/.checksums"

# Test 11: --fix creates missing version file
describe "doctor --fix creates missing version file"
rm -f ".right-hooks/version"
node "$CLI" doctor --fix >"$TEST_TMPDIR/fix-version" 2>&1
assert_file_exists ".right-hooks/version"

# Test 12: doctor without --fix only diagnoses
describe "doctor without --fix does not repair"
rm -f ".right-hooks/hooks/judge.sh"
node "$CLI" doctor >"$TEST_TMPDIR/diag-only" 2>&1 || true
# judge.sh should still be missing (not auto-fixed)
if [ ! -f ".right-hooks/hooks/judge.sh" ]; then
  pass
else
  fail "Expected doctor without --fix to NOT restore hook"
fi
# Restore it for subsequent tests
node "$CLI" doctor --fix >/dev/null 2>&1

# Test 13: doctor --fix shows auto-fixed count
describe "doctor --fix shows fix summary"
rm -f ".right-hooks/.checksums"
rm -f ".right-hooks/version"
node "$CLI" doctor --fix >"$TEST_TMPDIR/fix-summary" 2>&1
assert_stdout_contains "auto-fixed" "$TEST_TMPDIR/fix-summary"

print_summary
