#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

CLI="$SCRIPT_DIR/../../../bin/right-hooks.js"

echo "cli/scaffold"

# Setup: create a bare project
cd "$TEST_TMPDIR"
git init -q
git commit --allow-empty -m "init" -q

# Test 1: scaffold creates docs/designs/
describe "scaffold creates docs/designs/"
node "$CLI" scaffold >/dev/null 2>&1
assert_dir_exists "docs/designs"

# Test 2: scaffold creates docs/exec-plans/
describe "scaffold creates docs/exec-plans/"
assert_dir_exists "docs/exec-plans"

# Test 3: scaffold creates docs/retros/
describe "scaffold creates docs/retros/"
assert_dir_exists "docs/retros"

# Test 4: .gitkeep exists in each directory
describe ".gitkeep in docs/designs/"
assert_file_exists "docs/designs/.gitkeep"

describe ".gitkeep in docs/exec-plans/"
assert_file_exists "docs/exec-plans/.gitkeep"

describe ".gitkeep in docs/retros/"
assert_file_exists "docs/retros/.gitkeep"

# Test 7: scaffold is idempotent
describe "scaffold is idempotent (second run exits 0)"
node "$CLI" scaffold >"$TEST_TMPDIR/scaffold-out" 2>&1
assert_exit_code 0 $?

# Test 8: idempotent run reports "already exists"
describe "idempotent run reports already exists"
assert_stdout_contains "already exists" "$TEST_TMPDIR/scaffold-out"

# Test 9: scaffold creates learned-patterns.md when missing
describe "scaffold creates learned-patterns.md"
mkdir -p ".right-hooks/rules"
# Remove if it was created
rm -f ".right-hooks/rules/learned-patterns.md"
node "$CLI" scaffold >/dev/null 2>&1
assert_file_exists ".right-hooks/rules/learned-patterns.md"

# Test 10: scaffold skips learned-patterns.md when it exists with content
describe "scaffold preserves existing learned-patterns.md"
echo "# My custom patterns" > ".right-hooks/rules/learned-patterns.md"
node "$CLI" scaffold >/dev/null 2>&1
assert_file_contains ".right-hooks/rules/learned-patterns.md" "My custom patterns"

# Test 11: init also runs scaffold
describe "init --yes also creates docs directories"
cd "$TEST_TMPDIR"
INIT_DIR="$TEST_TMPDIR/init-project"
mkdir -p "$INIT_DIR" && cd "$INIT_DIR"
git init -q && git commit --allow-empty -m "init" -q
node "$CLI" init --yes >/dev/null 2>&1
assert_dir_exists "docs/designs"

print_summary
