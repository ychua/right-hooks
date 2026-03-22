#!/usr/bin/env bash
# Tests for: subagent-stop-check.sh hook
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$(cd "$SCRIPT_DIR/../../" && pwd)/hooks/subagent-stop-check.sh"
PREAMBLE="$(cd "$SCRIPT_DIR/../../" && pwd)/hooks/_preamble.sh"

# Setup
cd "$TEST_TMPDIR"
git init -q
mkdir -p .right-hooks/hooks
cp "$PREAMBLE" .right-hooks/hooks/_preamble.sh
echo '{"name":"strict","gates":{"stopHook":true}}' > .right-hooks/active-profile.json

# --- non-stop command passes ---
describe "non-stop command exits 0"
echo '{"tool_input":{"command":"echo hello"}}' | RH_TEST=1 bash "$HOOK" >/dev/null 2>&1
assert_exit_code 0 $?

# --- empty input passes ---
describe "empty input exits 0"
echo '{}' | RH_TEST=1 bash "$HOOK" >/dev/null 2>&1
assert_exit_code 0 $?

# --- hook is executable ---
describe "hook file is valid bash"
bash -n "$HOOK"
assert_exit_code 0 $?

print_summary
