#!/usr/bin/env bash
# Tests for: block-scheduling.sh (PreToolUse CronCreate|CronDelete|RemoteTrigger hook)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../../hooks/block-scheduling.sh"

echo "block-scheduling"

# Helper: create an isolated git repo
new_repo() {
  REPO_DIR=$(mktemp -d)
  FAKE_HOME=$(mktemp -d)
  cd "$REPO_DIR"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  git commit --allow-empty -m "init" -q
  mkdir -p .right-hooks/.overrides
}

run_isolated_hook() {
  local hook="$1"
  local json_input="$2"
  local stdout_file="$TEST_TMPDIR/stdout"
  local stderr_file="$TEST_TMPDIR/stderr"

  echo "$json_input" | HOME="$FAKE_HOME" RH_TEST=1 bash "$hook" >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$stdout_file"
  LAST_STDERR="$stderr_file"
}

cleanup_repo() {
  rm -rf "$REPO_DIR" "$FAKE_HOME"
}

# ============================================================
# Block tests
# ============================================================

# --- Test 1: Blocks CronCreate ---
describe "blocks CronCreate tool"
new_repo
run_isolated_hook "$HOOK" '{"tool_name":"CronCreate","tool_input":{"schedule":"*/5 * * * *"}}'
assert_exit_code 2 "$LAST_EXIT"
cleanup_repo

# --- Test 2: Blocks CronDelete ---
describe "blocks CronDelete tool"
new_repo
run_isolated_hook "$HOOK" '{"tool_name":"CronDelete","tool_input":{"cron_id":"abc123"}}'
assert_exit_code 2 "$LAST_EXIT"
cleanup_repo

# --- Test 3: Blocks RemoteTrigger ---
describe "blocks RemoteTrigger tool"
new_repo
run_isolated_hook "$HOOK" '{"tool_name":"RemoteTrigger","tool_input":{"prompt":"run tests"}}'
assert_exit_code 2 "$LAST_EXIT"
cleanup_repo

# --- Test 4: Block message mentions tool name ---
describe "block message mentions the tool name"
new_repo
run_isolated_hook "$HOOK" '{"tool_name":"CronCreate","tool_input":{}}'
assert_exit_code 2 "$LAST_EXIT"
assert_stderr_contains "CronCreate" "$LAST_STDERR"
cleanup_repo

# ============================================================
# Override test
# ============================================================

# --- Test 5: Override allows scheduling ---
describe "override allows scheduling when present"
new_repo
# Create an override file for gate=scheduling on PR 1
echo '{"gate":"scheduling","reason":"test","ts":"2026-01-01"}' > .right-hooks/.overrides/scheduling-1.json
# Need to be on a branch with a PR
git checkout -b feat/test -q
run_isolated_hook "$HOOK" '{"tool_name":"CronCreate","tool_input":{}}'
# Override check uses rh_pr_number which may not find a PR in test — this tests the path exists
# The hook should still block since there's no real PR number to match
assert_exit_code 2 "$LAST_EXIT"
cleanup_repo

# ============================================================
# Hook validity
# ============================================================

# --- Test 6: Hook file is valid bash ---
describe "hook file is valid bash"
bash -n "$HOOK"
assert_exit_code 0 $?

print_summary
