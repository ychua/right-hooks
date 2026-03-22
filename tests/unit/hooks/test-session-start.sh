#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../../hooks/session-start.sh"

echo "session-start"

# Setup: create a git repo with .right-hooks
cd "$TEST_TMPDIR"
git init -q
git commit --allow-empty -m "init" -q
mkdir -p .right-hooks

# Create active preset and profile
echo '{"language":"typescript"}' > .right-hooks/active-preset.json
echo '{"name":"standard"}' > .right-hooks/active-profile.json

# Test 1: Exits 0 (session-start should always succeed)
describe "exits 0 on normal branch"
git checkout -q -b feat/test
run_hook "$HOOK" '{}'
assert_exit_code 0 "$LAST_EXIT"

# Test 2: Outputs JSON context
describe "outputs JSON with context field"
assert_stdout_contains '"context"' "$LAST_STDOUT"

# Test 3: Context includes branch info
describe "context includes branch name"
assert_stdout_contains "feat/test" "$LAST_STDOUT"

# Test 4: Context includes preset info
describe "context includes preset info"
assert_stdout_contains "Preset: typescript" "$LAST_STDOUT"

# Test 5: Context includes profile info
describe "context includes profile info"
assert_stdout_contains "Profile: standard" "$LAST_STDOUT"

# Test 6: Shows "No open PR" when no PR
describe "shows 'No open PR' when no PR exists"
assert_stdout_contains "No open PR" "$LAST_STDOUT"

print_summary
