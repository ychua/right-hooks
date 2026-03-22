#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../../hooks/block-agent-override.sh"

echo "block-agent-override"

# Test 1: Block 'right-hooks override'
describe "blocks right-hooks override command"
run_hook "$HOOK" '{"tool_input":{"command":"npx right-hooks override --gate=qa --reason=skip"}}'
assert_exit_code 2 "$LAST_EXIT"

# Test 2: Stderr contains helpful message
describe "stderr says only humans can override"
assert_stderr_contains "only humans can override gates" "$LAST_STDERR"

# Test 3: Block with different spacing
describe "blocks right-hooks  override (extra space)"
run_hook "$HOOK" '{"tool_input":{"command":"npx right-hooks  override"}}'
assert_exit_code 2 "$LAST_EXIT"

# Test 4: Allow right-hooks status
describe "allows right-hooks status"
run_hook "$HOOK" '{"tool_input":{"command":"npx right-hooks status"}}'
assert_exit_code 0 "$LAST_EXIT"

# Test 5: Allow right-hooks doctor
describe "allows right-hooks doctor"
run_hook "$HOOK" '{"tool_input":{"command":"npx right-hooks doctor"}}'
assert_exit_code 0 "$LAST_EXIT"

# Test 6: Allow unrelated commands
describe "allows unrelated commands"
run_hook "$HOOK" '{"tool_input":{"command":"npm test"}}'
assert_exit_code 0 "$LAST_EXIT"

print_summary
