#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

CLI="$SCRIPT_DIR/../../bin/right-hooks.js"

echo "cli/init"

# Setup: create a temp project with tsconfig.json
cd "$TEST_TMPDIR"
git init -q
git commit --allow-empty -m "init" -q
echo '{"compilerOptions":{}}' > tsconfig.json

# Test 1: init --yes creates .right-hooks directory
describe "init --yes creates .right-hooks/"
node "$CLI" init --yes >/dev/null 2>&1
assert_dir_exists ".right-hooks"

# Test 2: hooks directory exists
describe "creates hooks directory"
assert_dir_exists ".right-hooks/hooks"

# Test 3: preamble exists
describe "installs _preamble.sh"
assert_file_exists ".right-hooks/hooks/_preamble.sh"

# Test 4: pre-push-master hook exists
describe "installs pre-push-master.sh"
assert_file_exists ".right-hooks/hooks/pre-push-master.sh"

# Test 5: active-preset.json exists with typescript
describe "sets active preset to typescript"
assert_file_exists ".right-hooks/active-preset.json"

# Test 6: active preset is typescript (detected from tsconfig.json)
describe "detects typescript from tsconfig.json"
assert_file_contains ".right-hooks/active-preset.json" '"typescript"'

# Test 7: .claude directory exists
describe "creates .claude/ directory"
assert_dir_exists ".claude"

# Test 8: .claude/settings.json exists
describe "creates .claude/settings.json"
assert_file_exists ".claude/settings.json"

# Test 9: rules are symlinked
describe "creates .claude/rules/"
assert_dir_exists ".claude/rules"

# Test 10: version file exists
describe "writes version file"
assert_file_exists ".right-hooks/version"

# Test 11: checksums file exists
describe "writes checksums file"
assert_file_exists ".right-hooks/.checksums"

# Test 12: profiles directory
describe "creates profiles directory"
assert_dir_exists ".right-hooks/profiles"

# Test 13: templates directory
describe "creates templates directory"
assert_dir_exists ".right-hooks/templates"

print_summary
