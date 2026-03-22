#!/usr/bin/env bash
# RIGHT-HOOKS Test Helpers — zero dependencies, pure bash

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Setup test environment
setup_test_env() {
  export RH_TEST=1
  TEST_TMPDIR=$(mktemp -d)
  # Ensure cleanup on exit
  trap 'rm -rf "$TEST_TMPDIR"' EXIT
}

# Describe a test
describe() {
  CURRENT_TEST="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
}

# Pass
pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST"
}

# Fail
fail() {
  local msg="${1:-}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST"
  if [ -n "$msg" ]; then
    echo -e "    ${RED}→ $msg${NC}"
  fi
}

# Assert exit code
assert_exit_code() {
  local expected="$1"
  local actual="$2"
  if [ "$actual" -eq "$expected" ]; then
    pass
  else
    fail "Expected exit code $expected, got $actual"
  fi
}

# Assert stderr contains string
assert_stderr_contains() {
  local expected="$1"
  local stderr_file="$2"
  if grep -qF "$expected" "$stderr_file" 2>/dev/null; then
    pass
  else
    fail "Expected stderr to contain: '$expected'"
    echo "    Actual stderr: $(cat "$stderr_file" 2>/dev/null)"
  fi
}

# Assert stderr matches regex
assert_stderr_matches() {
  local pattern="$1"
  local stderr_file="$2"
  if grep -qE "$pattern" "$stderr_file" 2>/dev/null; then
    pass
  else
    fail "Expected stderr to match: '$pattern'"
    echo "    Actual stderr: $(cat "$stderr_file" 2>/dev/null)"
  fi
}

# Assert file exists
assert_file_exists() {
  local file="$1"
  if [ -f "$file" ]; then
    pass
  else
    fail "Expected file to exist: $file"
  fi
}

# Assert directory exists
assert_dir_exists() {
  local dir="$1"
  if [ -d "$dir" ]; then
    pass
  else
    fail "Expected directory to exist: $dir"
  fi
}

# Assert file contains string
assert_file_contains() {
  local file="$1"
  local expected="$2"
  if grep -qF "$expected" "$file" 2>/dev/null; then
    pass
  else
    fail "Expected $file to contain: '$expected'"
  fi
}

# Assert stdout contains string
assert_stdout_contains() {
  local expected="$1"
  local stdout_file="$2"
  if grep -qF "$expected" "$stdout_file" 2>/dev/null; then
    pass
  else
    fail "Expected stdout to contain: '$expected'"
    echo "    Actual stdout: $(cat "$stdout_file" 2>/dev/null)"
  fi
}

# Run a hook with JSON input, capture exit code and stderr
# Uses env -i to guarantee a clean environment — no inherited git vars from CI
run_hook() {
  local hook="$1"
  local json_input="$2"
  local stdout_file="$TEST_TMPDIR/stdout"
  local stderr_file="$TEST_TMPDIR/stderr"
  local cwd
  cwd=$(pwd)

  echo "$json_input" | env -i HOME="$HOME" PATH="$PATH" TERM="${TERM:-dumb}" RH_TEST=1 bash -c 'cd "$1" && exec bash "$2"' _ "$cwd" "$hook" >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$stdout_file"
  LAST_STDERR="$stderr_file"
}

# Print test summary
print_summary() {
  echo ""
  echo "─────────────────────────────────"
  if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All $TESTS_PASSED tests passed${NC}"
  else
    echo -e "${RED}$TESTS_FAILED failed${NC}, ${GREEN}$TESTS_PASSED passed${NC} out of $TESTS_RUN tests"
  fi
  echo "─────────────────────────────────"
  return "$TESTS_FAILED"
}
