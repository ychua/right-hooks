#!/usr/bin/env bash
# Tests for: src/gates.js (shared gate registry)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

CLI="$(cd "$SCRIPT_DIR/../../../" && pwd)/bin/right-hooks.js"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"

cd "$TEST_TMPDIR"

# We test gates.js by requiring it directly via node -e
GATES_PATH="$PROJECT_ROOT/src/gates.js"

# --- getAllGateNames returns all 10 gates ---
describe "getAllGateNames returns all 10 gates"
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  const names = g.getAllGateNames();
  console.log(names.length);
  console.log(names.join(','));
" 2>&1)
COUNT=$(echo "$OUTPUT" | head -1)
if [ "$COUNT" = "10" ]; then
  pass
else
  fail "Expected 10 gates, got: $COUNT"
fi

# --- getAllGateNames includes all expected gate names ---
describe "getAllGateNames includes all expected gate names"
NAMES=$(echo "$OUTPUT" | tail -1)
ALL_FOUND=true
for gate in ci dod docConsistency planningArtifacts engReview codeReview qa learnings stopHook postEditCheck; do
  if ! echo "$NAMES" | grep -q "$gate"; then
    ALL_FOUND=false
    break
  fi
done
if [ "$ALL_FOUND" = "true" ]; then
  pass
else
  fail "Missing gate names in: $NAMES"
fi

# --- getGateInfo returns info for known gate ---
describe "getGateInfo returns info for known gate"
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  const info = g.getGateInfo('ci');
  console.log(typeof info.description);
  console.log(typeof info.howToSatisfy);
  console.log(typeof info.howToOverride);
  console.log(typeof info.alwaysOn);
" 2>&1)
if echo "$OUTPUT" | grep -q "string" && echo "$OUTPUT" | grep -q "boolean"; then
  pass
else
  fail "Expected string/boolean types, got: $OUTPUT"
fi

# --- getGateInfo returns null for unknown gate ---
describe "getGateInfo returns null for unknown gate"
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  console.log(g.getGateInfo('nonexistent'));
" 2>&1)
if echo "$OUTPUT" | grep -q "null"; then
  pass
else
  fail "Expected null, got: $OUTPUT"
fi

# --- ci and docConsistency are alwaysOn ---
describe "ci and docConsistency are alwaysOn"
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  console.log(g.getGateInfo('ci').alwaysOn);
  console.log(g.getGateInfo('docConsistency').alwaysOn);
" 2>&1)
if echo "$OUTPUT" | grep -c "true" | grep -q "2"; then
  pass
else
  fail "Expected both true, got: $OUTPUT"
fi

# --- non-alwaysOn gates have alwaysOn false ---
describe "non-alwaysOn gates have alwaysOn false"
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  console.log(g.getGateInfo('dod').alwaysOn);
  console.log(g.getGateInfo('qa').alwaysOn);
  console.log(g.getGateInfo('learnings').alwaysOn);
" 2>&1)
if echo "$OUTPUT" | grep -c "false" | grep -q "3"; then
  pass
else
  fail "Expected all false, got: $OUTPUT"
fi

# --- suggestGate finds close match ---
describe "suggestGate finds close match for typo"
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  console.log(g.suggestGate('codeReveiw'));
" 2>&1)
if echo "$OUTPUT" | grep -q "codeReview"; then
  pass
else
  fail "Expected 'codeReview' suggestion, got: $OUTPUT"
fi

# --- suggestGate returns null for distant input ---
describe "suggestGate returns null for distant input"
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  console.log(g.suggestGate('xyzabc123'));
" 2>&1)
if echo "$OUTPUT" | grep -q "null"; then
  pass
else
  fail "Expected null for distant input, got: $OUTPUT"
fi

# --- levenshtein distance is correct ---
describe "levenshtein distance computation is correct"
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  console.log(g.levenshtein('kitten', 'sitting'));
  console.log(g.levenshtein('', 'abc'));
  console.log(g.levenshtein('abc', 'abc'));
" 2>&1)
EXPECTED=$'3\n3\n0'
if [ "$OUTPUT" = "$EXPECTED" ]; then
  pass
else
  fail "Expected 3,3,0 got: $OUTPUT"
fi

# --- getActiveGates reads profiles ---
describe "getActiveGates reads profiles directory"
mkdir -p profiles
cat > profiles/test.json << 'EOF'
{"name":"test","gates":{"ci":true,"dod":false,"qa":true}}
EOF
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  const active = g.getActiveGates('$TEST_TMPDIR/profiles');
  console.log(active.ci.test);
  console.log(active.dod.test);
  console.log(active.qa.test);
" 2>&1)
EXPECTED=$'true\nfalse\ntrue'
if [ "$OUTPUT" = "$EXPECTED" ]; then
  pass
else
  fail "Expected true,false,true got: $OUTPUT"
fi

# --- getActiveGates forces alwaysOn gates to true ---
describe "getActiveGates forces alwaysOn gates to true even if profile says false"
cat > profiles/override.json << 'EOF'
{"name":"override","gates":{"ci":false,"docConsistency":false}}
EOF
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  const active = g.getActiveGates('$TEST_TMPDIR/profiles');
  console.log(active.ci.override);
  console.log(active.docConsistency.override);
" 2>&1)
EXPECTED=$'true\ntrue'
if [ "$OUTPUT" = "$EXPECTED" ]; then
  pass
else
  fail "Expected true,true for alwaysOn gates, got: $OUTPUT"
fi

# --- validateRegistry warns on unknown gates ---
describe "validateRegistry warns on unknown gates in profiles"
mkdir -p badprofiles
cat > badprofiles/bad.json << 'EOF'
{"name":"bad","gates":{"ci":true,"nonexistentGate":true}}
EOF
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  const warnings = g.validateRegistry('$TEST_TMPDIR/badprofiles');
  console.log(warnings.length);
  console.log(warnings[0]);
" 2>&1)
if echo "$OUTPUT" | grep -q "unknown gate" && echo "$OUTPUT" | grep -q "nonexistentGate"; then
  pass
else
  fail "Expected warning about unknown gate, got: $OUTPUT"
fi

# --- validateRegistry returns empty for valid profiles ---
describe "validateRegistry returns no warnings for valid profiles"
mkdir -p goodprofiles
cat > goodprofiles/good.json << 'EOF'
{"name":"good","gates":{"ci":true,"dod":false,"qa":true}}
EOF
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  const warnings = g.validateRegistry('$TEST_TMPDIR/goodprofiles');
  console.log(warnings.length);
" 2>&1)
if echo "$OUTPUT" | grep -q "0"; then
  pass
else
  fail "Expected 0 warnings, got: $OUTPUT"
fi

# --- validateRegistry handles missing directory ---
describe "validateRegistry handles missing directory gracefully"
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  const warnings = g.validateRegistry('$TEST_TMPDIR/nonexistent');
  console.log(warnings.length);
" 2>&1)
if echo "$OUTPUT" | grep -q "0"; then
  pass
else
  fail "Expected 0 warnings for missing dir, got: $OUTPUT"
fi

# --- validateRegistry includes suggestion for close typos ---
describe "validateRegistry suggests correct gate name for typos"
mkdir -p typoprofiles
cat > typoprofiles/typo.json << 'EOF'
{"name":"typo","gates":{"codeReveiw":true}}
EOF
OUTPUT=$(node -e "
  const g = require('$GATES_PATH');
  const warnings = g.validateRegistry('$TEST_TMPDIR/typoprofiles');
  console.log(warnings[0]);
" 2>&1)
if echo "$OUTPUT" | grep -q 'did you mean "codeReview"'; then
  pass
else
  fail "Expected suggestion for codeReview, got: $OUTPUT"
fi

print_summary
