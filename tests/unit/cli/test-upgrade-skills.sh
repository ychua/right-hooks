#!/usr/bin/env bash
# Tests for: upgrade now merges new skills.json fields
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

BIN="$(cd "$SCRIPT_DIR/../../../" && pwd)/bin/right-hooks.js"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../" && pwd)"

echo "cli/upgrade-skills"

# Setup: create a project with init
cd "$TEST_TMPDIR"
git init -q
echo '{}' > tsconfig.json
RH_TEST=1 node "$BIN" init --yes >/dev/null 2>&1

# --- Test: upgrade adds new skillSignature field to existing skills.json ---
describe "upgrade adds skillSignature to existing skills.json"
# Simulate older skills.json without skillSignature
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.right-hooks/skills.json', 'utf8'));
  for (const gate of Object.keys(s)) {
    delete s[gate].skillSignature;
  }
  fs.writeFileSync('.right-hooks/skills.json', JSON.stringify(s, null, 2));
"
echo "0.9.0" > .right-hooks/version
node "$BIN" upgrade >/dev/null 2>&1 || true
# Now check that skillSignature was added back
HAS_SIG=$(node -e "
  const s = JSON.parse(require('fs').readFileSync('.right-hooks/skills.json','utf8'));
  const hasSig = Object.values(s).some(g => 'skillSignature' in g);
  process.stdout.write(hasSig ? 'yes' : 'no');
")
if [ "$HAS_SIG" = "yes" ]; then
  pass
else
  fail "skillSignature was not added by upgrade"
fi

# --- Test: upgrade preserves user's skill/provider/fallback choices ---
describe "upgrade preserves user's skill, provider, fallback choices"
# Set custom skill/provider/fallback
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.right-hooks/skills.json', 'utf8'));
  s.codeReview.skill = '/my-custom-review';
  s.codeReview.provider = 'my-tool';
  s.codeReview.fallback = 'My custom fallback';
  // Remove skillSignature to trigger merge
  delete s.codeReview.skillSignature;
  fs.writeFileSync('.right-hooks/skills.json', JSON.stringify(s, null, 2));
"
echo "0.9.0" > .right-hooks/version
node "$BIN" upgrade >/dev/null 2>&1 || true
node -e "
  const s = JSON.parse(require('fs').readFileSync('.right-hooks/skills.json','utf8'));
  if (s.codeReview.skill !== '/my-custom-review') { console.error('skill changed'); process.exit(1); }
  if (s.codeReview.provider !== 'my-tool') { console.error('provider changed'); process.exit(1); }
  if (s.codeReview.fallback !== 'My custom fallback') { console.error('fallback changed'); process.exit(1); }
  process.exit(0);
"
if [ $? -eq 0 ]; then
  pass
else
  fail "User's skill/provider/fallback choices were overwritten"
fi

# --- Test: upgrade does not overwrite existing fields ---
describe "upgrade does not overwrite fields the user already has"
# User has a custom skillSignature already
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.right-hooks/skills.json', 'utf8'));
  s.codeReview.skillSignature = 'MyCustomPattern';
  fs.writeFileSync('.right-hooks/skills.json', JSON.stringify(s, null, 2));
"
echo "0.9.0" > .right-hooks/version
node "$BIN" upgrade >/dev/null 2>&1 || true
SIG=$(node -e "
  const s = JSON.parse(require('fs').readFileSync('.right-hooks/skills.json','utf8'));
  process.stdout.write(s.codeReview.skillSignature || '');
")
if [ "$SIG" = "MyCustomPattern" ]; then
  pass
else
  fail "Existing skillSignature was overwritten: got '$SIG'"
fi

# --- Test: upgrade adds new gates that ship with newer versions ---
describe "upgrade adds new gates from shipped config"
# Remove a gate entirely from user's skills.json
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.right-hooks/skills.json', 'utf8'));
  delete s.docConsistency;
  fs.writeFileSync('.right-hooks/skills.json', JSON.stringify(s, null, 2));
"
echo "0.9.0" > .right-hooks/version
node "$BIN" upgrade >/dev/null 2>&1 || true
HAS_DOC=$(node -e "
  const s = JSON.parse(require('fs').readFileSync('.right-hooks/skills.json','utf8'));
  process.stdout.write(s.docConsistency ? 'yes' : 'no');
")
if [ "$HAS_DOC" = "yes" ]; then
  pass
else
  fail "docConsistency gate was not added by upgrade"
fi

# --- Test: upgrade reports skills merge ---
describe "upgrade reports skills.json merge"
# Remove skillSignature so merge has something to do
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.right-hooks/skills.json', 'utf8'));
  delete s.qa.skillSignature;
  fs.writeFileSync('.right-hooks/skills.json', JSON.stringify(s, null, 2));
"
echo "0.9.0" > .right-hooks/version
OUTPUT=$(node "$BIN" upgrade 2>&1 || true)
if echo "$OUTPUT" | grep -qi "skills.json.*merged\|skills.json.*updated"; then
  pass
else
  fail "Expected upgrade output to mention skills.json merge: $OUTPUT"
fi

print_summary
