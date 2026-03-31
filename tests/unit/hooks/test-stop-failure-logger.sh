#!/usr/bin/env bash
# Tests for: stop-failure-logger.sh (StopFailure hook)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../../hooks/stop-failure-logger.sh"

echo "stop-failure-logger"

# Helper: create an isolated git repo
new_repo() {
  REPO_DIR=$(mktemp -d)
  FAKE_HOME=$(mktemp -d)
  cd "$REPO_DIR"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  git commit --allow-empty -m "init" -q
  mkdir -p .right-hooks
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
# Non-blocking behavior
# ============================================================

# --- Test 1: Always exits 0 (non-blocking) ---
describe "always exits 0 (non-blocking, observability only)"
new_repo
run_isolated_hook "$HOOK" '{"error":"rate_limit","error_details":"Too many requests"}'
assert_exit_code 0 "$LAST_EXIT"
cleanup_repo

# --- Test 2: Records event to .stats ---
describe "records failure event to .stats/events.jsonl"
new_repo
run_isolated_hook "$HOOK" '{"error":"rate_limit","error_details":"Too many requests"}'
assert_exit_code 0 "$LAST_EXIT"
assert_file_exists ".right-hooks/.stats/events.jsonl"
assert_file_contains ".right-hooks/.stats/events.jsonl" "stop_failure"
assert_file_contains ".right-hooks/.stats/events.jsonl" "rate_limit"
cleanup_repo

# --- Test 3: Handles missing error field ---
describe "handles missing error field (defaults to unknown)"
new_repo
run_isolated_hook "$HOOK" '{}'
assert_exit_code 0 "$LAST_EXIT"
assert_file_exists ".right-hooks/.stats/events.jsonl"
assert_file_contains ".right-hooks/.stats/events.jsonl" "unknown"
cleanup_repo

# --- Test 4: Creates .stats dir if missing ---
describe "creates .stats directory if it does not exist"
new_repo
# Explicitly remove .stats dir if it exists
rm -rf .right-hooks/.stats
run_isolated_hook "$HOOK" '{"error":"server_error"}'
assert_exit_code 0 "$LAST_EXIT"
assert_dir_exists ".right-hooks/.stats"
cleanup_repo

# ============================================================
# Hook validity
# ============================================================

# --- Test 5: Hook file is valid bash ---
describe "hook file is valid bash"
bash -n "$HOOK"
assert_exit_code 0 $?

print_summary
