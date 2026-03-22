#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

HOOK="$SCRIPT_DIR/../../../hooks/pre-pr-create.sh"

echo "pre-pr-create"

# Helper: create an isolated git repo and cd into it
# Sets REPO_DIR to the created directory
# Usage: new_repo <default_branch> <feature_branch>
new_repo() {
  REPO_DIR=$(mktemp -d)
  cd "$REPO_DIR"
  git init -q
  git commit --allow-empty -m "init" -q
  git branch -M "$1"
  git checkout -q -b "$2"
}

# --- Test 1: Block PR create on feat/ without design doc ---
describe "blocks PR create on feat/ without design doc"
new_repo master feat/new-feature
echo "feature code" > feature.ts
git add feature.ts && git commit -q -m "add feature"
run_hook "$HOOK" '{"tool_input":{"command":"gh pr create --title test"}}'
assert_exit_code 2 "$LAST_EXIT"
rm -rf "$REPO_DIR"

# --- Test 2: Stderr mentions missing design doc ---
describe "stderr mentions missing design doc"
new_repo master feat/test2
echo "code" > code.ts
git add code.ts && git commit -q -m "add code"
run_hook "$HOOK" '{"tool_input":{"command":"gh pr create --title test"}}'
assert_stderr_contains "Missing design doc" "$LAST_STDERR"
rm -rf "$REPO_DIR"

# --- Test 3: Stderr mentions missing exec plan ---
describe "stderr mentions missing exec plan"
new_repo master feat/test3
echo "code" > code.ts
git add code.ts && git commit -q -m "add code"
run_hook "$HOOK" '{"tool_input":{"command":"gh pr create --title test"}}'
assert_stderr_contains "Missing exec plan" "$LAST_STDERR"
rm -rf "$REPO_DIR"

# --- Test 4: Allow PR create on fix/ branch ---
describe "allows PR create on fix/ branch"
new_repo master fix/bugfix
echo "fix" > fix.ts
git add fix.ts && git commit -q -m "fix"
run_hook "$HOOK" '{"tool_input":{"command":"gh pr create --title fix"}}'
assert_exit_code 0 "$LAST_EXIT"
rm -rf "$REPO_DIR"

# --- Test 5: Allow PR create on docs/ branch ---
describe "allows PR create on docs/ branch"
new_repo master docs/update
echo "doc" > doc.md
git add doc.md && git commit -q -m "doc"
run_hook "$HOOK" '{"tool_input":{"command":"gh pr create --title docs"}}'
assert_exit_code 0 "$LAST_EXIT"
rm -rf "$REPO_DIR"

# --- Test 6: Allow non-PR commands on feat/ branch ---
describe "allows non-PR commands on feat/ branch"
new_repo master feat/test6
run_hook "$HOOK" '{"tool_input":{"command":"git status"}}'
assert_exit_code 0 "$LAST_EXIT"
rm -rf "$REPO_DIR"

# --- Test 7: Works with 'main' as default branch ---
describe "detects design doc with main as default branch"
new_repo main feat/main-test
mkdir -p docs/designs docs/exec-plans
echo "# Design" > docs/designs/main-test.md
printf '# Exec Plan\n\n## Definition of Done\n- [ ] works\n' > docs/exec-plans/main-test.md
git add . && git commit -q -m "add planning docs"
run_hook "$HOOK" '{"tool_input":{"command":"gh pr create --title test"}}'
assert_exit_code 0 "$LAST_EXIT"
rm -rf "$REPO_DIR"

# --- Test 8: Blocks feat/ on main-based repo without docs ---
describe "blocks feat/ on main-based repo without design doc"
new_repo main feat/no-docs
echo "code" > code.js
git add code.js && git commit -q -m "code without docs"
run_hook "$HOOK" '{"tool_input":{"command":"gh pr create --title test"}}'
assert_exit_code 2 "$LAST_EXIT"
rm -rf "$REPO_DIR"

print_summary
