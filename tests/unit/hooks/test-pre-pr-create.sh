#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../../hooks/pre-pr-create.sh"

echo "pre-pr-create"

# Setup: create a git repo with master branch and a feat/ branch
cd "$TEST_TMPDIR"
git init -q
git commit --allow-empty -m "init" -q
git branch -M master

# Test 1: Block PR create on feat/ branch without design doc
describe "blocks PR create on feat/ without design doc"
git checkout -q -b feat/new-feature
# Add a file to create a diff against master
echo "feature code" > feature.ts
git add feature.ts && git commit -q -m "add feature"
run_hook "$HOOK" '{"tool_input":{"command":"gh pr create --title test"}}'
assert_exit_code 2 "$LAST_EXIT"

# Test 2: Stderr mentions missing design doc
describe "stderr mentions missing design doc"
assert_stderr_contains "Missing design doc" "$LAST_STDERR"

# Test 3: Stderr mentions missing exec plan
describe "stderr mentions missing exec plan"
assert_stderr_contains "Missing exec plan" "$LAST_STDERR"

# Test 4: Allow PR create on fix/ branch (no planning required)
describe "allows PR create on fix/ branch"
git checkout -q -b fix/bugfix
run_hook "$HOOK" '{"tool_input":{"command":"gh pr create --title fix"}}'
assert_exit_code 0 "$LAST_EXIT"

# Test 5: Allow PR create on docs/ branch
describe "allows PR create on docs/ branch"
git checkout -q -b docs/update
run_hook "$HOOK" '{"tool_input":{"command":"gh pr create --title docs"}}'
assert_exit_code 0 "$LAST_EXIT"

# Test 6: Allow non-PR commands on feat/ branch
describe "allows non-PR commands on feat/ branch"
git checkout -q feat/new-feature
run_hook "$HOOK" '{"tool_input":{"command":"git status"}}'
assert_exit_code 0 "$LAST_EXIT"

print_summary
