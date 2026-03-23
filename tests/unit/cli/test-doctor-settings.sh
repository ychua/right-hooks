#!/usr/bin/env bash
# Tests for: doctor verifies settings.json completeness
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

BIN="$(cd "$SCRIPT_DIR/../../../" && pwd)/bin/right-hooks.js"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../" && pwd)"

echo "cli/doctor-settings"

# Setup: create a project with init
cd "$TEST_TMPDIR"
git init -q
git commit --allow-empty -m "init" -q
echo '{}' > tsconfig.json
RH_TEST=1 node "$BIN" init --yes >/dev/null 2>&1

# --- Test: doctor passes with complete settings.json ---
describe "doctor passes with complete settings.json"
OUTPUT=$(node "$BIN" doctor 2>&1)
EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
  pass
else
  fail "Expected exit 0 with complete settings, got $EXIT_CODE"
fi

# --- Test: doctor detects missing hook event registrations ---
describe "doctor detects missing SubagentStart registration"
# Remove SubagentStart from settings
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.claude/settings.json', 'utf8'));
  delete s.hooks.SubagentStart;
  fs.writeFileSync('.claude/settings.json', JSON.stringify(s, null, 2));
"
OUTPUT=$(node "$BIN" doctor 2>&1 || true)
if echo "$OUTPUT" | grep -qi "SubagentStart"; then
  pass
else
  fail "Expected doctor to report missing SubagentStart: $OUTPUT"
fi

# --- Test: doctor detects missing hook commands within events ---
describe "doctor detects missing hook commands within events"
# Remove workflow-orchestrator from PostToolUse
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.claude/settings.json', 'utf8'));
  s.hooks.PostToolUse = s.hooks.PostToolUse.filter(
    e => !(e.matcher === 'Bash')
  );
  fs.writeFileSync('.claude/settings.json', JSON.stringify(s, null, 2));
"
OUTPUT=$(node "$BIN" doctor 2>&1 || true)
if echo "$OUTPUT" | grep -qi "workflow-orchestrator\|missing.*hook.*registration\|Missing.*command"; then
  pass
else
  fail "Expected doctor to report missing workflow-orchestrator command: $OUTPUT"
fi

# --- Test: doctor --fix adds missing hook event registrations ---
describe "doctor --fix adds missing SubagentStart registration"
# Remove SubagentStart again
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.claude/settings.json', 'utf8'));
  delete s.hooks.SubagentStart;
  fs.writeFileSync('.claude/settings.json', JSON.stringify(s, null, 2));
"
node "$BIN" doctor --fix >/dev/null 2>&1 || true
# Verify it was added
if node -e "
  const s = JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'));
  process.exit(s.hooks.SubagentStart ? 0 : 1);
"; then
  pass
else
  fail "SubagentStart was not added by doctor --fix"
fi

# --- Test: doctor --fix adds missing commands within events ---
describe "doctor --fix adds missing commands within events"
# Remove workflow-orchestrator from PostToolUse
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.claude/settings.json', 'utf8'));
  s.hooks.PostToolUse = s.hooks.PostToolUse.filter(
    e => !(e.matcher === 'Bash')
  );
  fs.writeFileSync('.claude/settings.json', JSON.stringify(s, null, 2));
"
node "$BIN" doctor --fix >/dev/null 2>&1 || true
if node -e "
  const s = JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'));
  const cmds = s.hooks.PostToolUse.flatMap(e => (e.hooks||[]).map(h => h.command));
  process.exit(cmds.some(c => c.includes('workflow-orchestrator')) ? 0 : 1);
"; then
  pass
else
  fail "workflow-orchestrator was not added by doctor --fix"
fi

# --- Test: doctor --fix reports what it fixed ---
describe "doctor --fix reports settings.json fix"
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.claude/settings.json', 'utf8'));
  delete s.hooks.SessionStart;
  fs.writeFileSync('.claude/settings.json', JSON.stringify(s, null, 2));
"
OUTPUT=$(node "$BIN" doctor --fix 2>&1 || true)
if echo "$OUTPUT" | grep -qi "settings.json\|hook registration"; then
  pass
else
  fail "Expected doctor --fix to report settings fix: $OUTPUT"
fi

# --- Test: doctor without --fix does not modify settings ---
describe "doctor without --fix does not modify settings.json"
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.claude/settings.json', 'utf8'));
  delete s.hooks.ConfigChange;
  fs.writeFileSync('.claude/settings.json', JSON.stringify(s, null, 2));
"
BEFORE=$(cat .claude/settings.json)
node "$BIN" doctor 2>&1 || true
AFTER=$(cat .claude/settings.json)
if [ "$BEFORE" = "$AFTER" ]; then
  pass
else
  fail "Expected settings.json to be unchanged without --fix"
fi

print_summary
