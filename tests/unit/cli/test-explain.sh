#!/usr/bin/env bash
# Tests for: npx right-hooks explain CLI command
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

CLI="$(cd "$SCRIPT_DIR/../../../" && pwd)/bin/right-hooks.js"

cd "$TEST_TMPDIR"

# --- explain with no args lists all gates ---
describe "explain with no args lists all gates"
OUTPUT=$(node "$CLI" explain 2>&1 || true)
if echo "$OUTPUT" | grep -q "ci" && echo "$OUTPUT" | grep -q "qa" && echo "$OUTPUT" | grep -q "codeReview"; then
  pass
else
  fail "Expected gate list in output, got: $OUTPUT"
fi

# --- explain with no args shows header ---
describe "explain with no args shows header"
OUTPUT=$(node "$CLI" explain 2>&1 || true)
if echo "$OUTPUT" | grep -q "Right Hooks Gates"; then
  pass
else
  fail "Expected 'Right Hooks Gates' header, got: $OUTPUT"
fi

# --- explain ci shows description ---
describe "explain ci shows description"
OUTPUT=$(node "$CLI" explain ci 2>&1 || true)
if echo "$OUTPUT" | grep -q "What it checks"; then
  pass
else
  fail "Expected 'What it checks' section, got: $OUTPUT"
fi

# --- explain ci shows how to satisfy ---
describe "explain ci shows how to satisfy"
OUTPUT=$(node "$CLI" explain ci 2>&1 || true)
if echo "$OUTPUT" | grep -q "How to satisfy"; then
  pass
else
  fail "Expected 'How to satisfy' section, got: $OUTPUT"
fi

# --- explain ci shows how to override ---
describe "explain ci shows how to override"
OUTPUT=$(node "$CLI" explain ci 2>&1 || true)
if echo "$OUTPUT" | grep -q "How to override"; then
  pass
else
  fail "Expected 'How to override' section, got: $OUTPUT"
fi

# --- explain ci shows always on ---
describe "explain ci shows always on tag"
OUTPUT=$(node "$CLI" explain ci 2>&1 || true)
if echo "$OUTPUT" | grep -q "always on"; then
  pass
else
  fail "Expected 'always on' tag for ci, got: $OUTPUT"
fi

# --- explain codeReview shows correct info ---
describe "explain codeReview shows severity markers info"
OUTPUT=$(node "$CLI" explain codeReview 2>&1 || true)
if echo "$OUTPUT" | grep -q "severity"; then
  pass
else
  fail "Expected severity info for codeReview, got: $OUTPUT"
fi

# --- explain unknown gate shows error ---
describe "explain unknown gate shows error"
OUTPUT=$(node "$CLI" explain foobar 2>&1 || true)
if echo "$OUTPUT" | grep -q 'Unknown gate: "foobar"'; then
  pass
else
  fail "Expected unknown gate error, got: $OUTPUT"
fi

# --- explain unknown gate lists available gates ---
describe "explain unknown gate lists available gates"
OUTPUT=$(node "$CLI" explain foobar 2>&1 || true)
if echo "$OUTPUT" | grep -q "Available gates"; then
  pass
else
  fail "Expected available gates list, got: $OUTPUT"
fi

# --- explain typo suggests correct gate ---
describe "explain typo suggests correct gate"
OUTPUT=$(node "$CLI" explain codeReveiw 2>&1 || true)
if echo "$OUTPUT" | grep -q 'Did you mean "codeReview"'; then
  pass
else
  fail "Expected 'Did you mean' suggestion, got: $OUTPUT"
fi

# --- explain with profiles shows table ---
describe "explain with profiles shows on/off table"
mkdir -p .right-hooks/profiles
cat > .right-hooks/profiles/strict.json << 'EOF'
{"name":"strict","gates":{"ci":true,"dod":true,"qa":true,"codeReview":true,"learnings":true,"docConsistency":true,"planningArtifacts":true,"engReview":true,"stopHook":true,"postEditCheck":true}}
EOF
cat > .right-hooks/profiles/light.json << 'EOF'
{"name":"light","gates":{"ci":true,"dod":true,"qa":false,"codeReview":false,"learnings":false,"docConsistency":true,"planningArtifacts":false,"engReview":false,"stopHook":false,"postEditCheck":true}}
EOF
OUTPUT=$(node "$CLI" explain 2>&1 || true)
if echo "$OUTPUT" | grep -q "strict" && echo "$OUTPUT" | grep -q "light"; then
  pass
else
  fail "Expected profile columns in table, got: $OUTPUT"
fi

# --- explain shows help hint ---
describe "explain shows run hint"
OUTPUT=$(node "$CLI" explain 2>&1 || true)
if echo "$OUTPUT" | grep -q "npx right-hooks explain"; then
  pass
else
  fail "Expected explain hint, got: $OUTPUT"
fi

# --- explain each gate individually ---
describe "explain each gate returns without error"
ALL_OK=true
for gate in ci dod docConsistency planningArtifacts engReview codeReview qa learnings stopHook postEditCheck; do
  OUTPUT=$(node "$CLI" explain "$gate" 2>&1 || true)
  if ! echo "$OUTPUT" | grep -q "What it checks"; then
    ALL_OK=false
    break
  fi
done
if [ "$ALL_OK" = "true" ]; then
  pass
else
  fail "One or more gates failed to display properly"
fi

print_summary
