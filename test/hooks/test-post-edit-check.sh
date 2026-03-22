#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../hooks/post-edit-check.sh"

echo "post-edit-check"

# Setup: create a git repo with .right-hooks structure
cd "$TEST_TMPDIR"
git init -q
git commit --allow-empty -m "init" -q
mkdir -p .right-hooks

# Test 1: Allow when no active-preset.json (no validation configured)
describe "allows when no active-preset.json exists"
run_hook "$HOOK" '{"tool_result":{"file_path":"src/index.ts"}}'
assert_exit_code 0 "$LAST_EXIT"

# Test 2: Allow when active-preset.json has no postEditValidation
describe "allows when preset has no postEditValidation"
echo '{"language":"generic","postEditValidation":null}' > .right-hooks/active-preset.json
run_hook "$HOOK" '{"tool_result":{"file_path":"src/index.ts"}}'
assert_exit_code 0 "$LAST_EXIT"

# Test 3: Allow when file doesn't match pattern
describe "allows when file doesn't match pattern"
cat > .right-hooks/active-preset.json <<'EOF'
{"language":"typescript","postEditValidation":{"filePattern":"\\.ts$","command":"echo ok","sourceDirs":["src/"]},"orphanDetection":null}
EOF
run_hook "$HOOK" '{"tool_result":{"file_path":"README.md"}}'
assert_exit_code 0 "$LAST_EXIT"

# Test 4: Allow when validation command succeeds
describe "allows when validation command succeeds"
run_hook "$HOOK" '{"tool_result":{"file_path":"src/index.ts"}}'
assert_exit_code 0 "$LAST_EXIT"

# Test 5: Block when validation command fails
describe "blocks when validation command fails"
cat > .right-hooks/active-preset.json <<'EOF'
{"language":"typescript","postEditValidation":{"filePattern":"\\.ts$","command":"echo 'error TS2322: Type mismatch' >&2; exit 1","sourceDirs":["src/"]},"orphanDetection":null}
EOF
run_hook "$HOOK" '{"tool_result":{"file_path":"src/index.ts"}}'
assert_exit_code 2 "$LAST_EXIT"

# Test 6: Stderr shows validation errors on failure
describe "stderr shows validation errors"
assert_stderr_contains "validation failed" "$LAST_STDERR"

# Test 7: Allow when no file_path in input
describe "allows when no file_path in input"
run_hook "$HOOK" '{"tool_result":{}}'
assert_exit_code 0 "$LAST_EXIT"

print_summary
