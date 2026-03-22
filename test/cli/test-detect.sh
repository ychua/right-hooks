#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

# We'll test detect by running init --yes and checking the active preset
CLI="$SCRIPT_DIR/../../bin/right-hooks.js"

echo "cli/detect"

# Test 1: Detect TypeScript
describe "detects TypeScript from tsconfig.json"
PROJ="$TEST_TMPDIR/ts-proj"
mkdir -p "$PROJ" && cd "$PROJ"
git init -q && git commit --allow-empty -m "init" -q
echo '{}' > tsconfig.json
node "$CLI" init --yes >/dev/null 2>&1
assert_file_contains ".right-hooks/active-preset.json" '"typescript"'

# Test 2: Detect Python
describe "detects Python from pyproject.toml"
PROJ="$TEST_TMPDIR/py-proj"
mkdir -p "$PROJ" && cd "$PROJ"
git init -q && git commit --allow-empty -m "init" -q
echo '[project]' > pyproject.toml
node "$CLI" init --yes >/dev/null 2>&1
assert_file_contains ".right-hooks/active-preset.json" '"python"'

# Test 3: Detect Go
describe "detects Go from go.mod"
PROJ="$TEST_TMPDIR/go-proj"
mkdir -p "$PROJ" && cd "$PROJ"
git init -q && git commit --allow-empty -m "init" -q
echo 'module example.com/test' > go.mod
node "$CLI" init --yes >/dev/null 2>&1
assert_file_contains ".right-hooks/active-preset.json" '"go"'

# Test 4: Detect Rust
describe "detects Rust from Cargo.toml"
PROJ="$TEST_TMPDIR/rs-proj"
mkdir -p "$PROJ" && cd "$PROJ"
git init -q && git commit --allow-empty -m "init" -q
echo '[package]' > Cargo.toml
node "$CLI" init --yes >/dev/null 2>&1
assert_file_contains ".right-hooks/active-preset.json" '"rust"'

# Test 5: Fallback to generic
describe "falls back to generic when no markers"
PROJ="$TEST_TMPDIR/generic-proj"
mkdir -p "$PROJ" && cd "$PROJ"
git init -q && git commit --allow-empty -m "init" -q
echo "hello" > README.md
node "$CLI" init --yes >/dev/null 2>&1
assert_file_contains ".right-hooks/active-preset.json" '"generic"'

print_summary
