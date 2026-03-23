#!/usr/bin/env bash
# Tests for: upgrade now merges settings.json hook registrations
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

BIN="$(cd "$SCRIPT_DIR/../../../" && pwd)/bin/right-hooks.js"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../" && pwd)"

echo "cli/upgrade-settings"

# Setup: create a project with init, then simulate an older version
cd "$TEST_TMPDIR"
git init -q
echo '{}' > tsconfig.json
RH_TEST=1 node "$BIN" init --yes >/dev/null 2>&1

# Save the full shipped settings for comparison
SHIPPED_SETTINGS=$(cat "$PROJECT_DIR/settings.json")

# --- Test: upgrade adds missing hook events to settings.json ---
describe "upgrade adds missing SubagentStart hook event to settings.json"
# Simulate older install: remove SubagentStart from settings
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.claude/settings.json', 'utf8'));
  delete s.hooks.SubagentStart;
  fs.writeFileSync('.claude/settings.json', JSON.stringify(s, null, 2));
"
echo "0.9.0" > .right-hooks/version
node "$BIN" upgrade >/dev/null 2>&1 || true
if node -e "
  const s = JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'));
  process.exit(s.hooks.SubagentStart ? 0 : 1);
"; then
  pass
else
  fail "SubagentStart was not added by upgrade"
fi

# --- Test: upgrade adds missing commands within existing events ---
describe "upgrade adds new commands within existing hook events"
# Remove workflow-orchestrator from PostToolUse Bash matcher
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.claude/settings.json', 'utf8'));
  s.hooks.PostToolUse = s.hooks.PostToolUse.filter(
    e => !(e.matcher === 'Bash')
  );
  fs.writeFileSync('.claude/settings.json', JSON.stringify(s, null, 2));
"
echo "0.9.0" > .right-hooks/version
node "$BIN" upgrade >/dev/null 2>&1 || true
if node -e "
  const s = JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'));
  const cmds = s.hooks.PostToolUse.flatMap(e => (e.hooks||[]).map(h => h.command));
  process.exit(cmds.some(c => c.includes('workflow-orchestrator')) ? 0 : 1);
"; then
  pass
else
  fail "workflow-orchestrator was not added to PostToolUse"
fi

# --- Test: upgrade does not duplicate existing commands ---
describe "upgrade does not duplicate existing hook commands"
echo "0.9.0" > .right-hooks/version
node "$BIN" upgrade >/dev/null 2>&1 || true
STOP_COUNT=$(node -e "
  const s = JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'));
  const cmds = s.hooks.Stop.flatMap(e => (e.hooks||[]).map(h => h.command));
  const stopCmds = cmds.filter(c => c.includes('stop-check'));
  process.stdout.write(String(stopCmds.length));
")
if [ "$STOP_COUNT" = "1" ]; then
  pass
else
  fail "Expected 1 stop-check command, got $STOP_COUNT"
fi

# --- Test: upgrade preserves user's custom settings fields ---
describe "upgrade preserves user's custom settings fields"
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.claude/settings.json', 'utf8'));
  s.customUserField = 'keep-me';
  fs.writeFileSync('.claude/settings.json', JSON.stringify(s, null, 2));
"
echo "0.9.0" > .right-hooks/version
node "$BIN" upgrade >/dev/null 2>&1 || true
if node -e "
  const s = JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'));
  process.exit(s.customUserField === 'keep-me' ? 0 : 1);
"; then
  pass
else
  fail "Custom user field was lost"
fi

# --- Test: upgrade reports settings update ---
describe "upgrade reports settings.json update"
# Remove a hook event so the merge has something to do
node -e "
  const fs = require('fs');
  const s = JSON.parse(fs.readFileSync('.claude/settings.json', 'utf8'));
  delete s.hooks.SessionStart;
  fs.writeFileSync('.claude/settings.json', JSON.stringify(s, null, 2));
"
echo "0.9.0" > .right-hooks/version
OUTPUT=$(node "$BIN" upgrade 2>&1 || true)
if echo "$OUTPUT" | grep -qi "settings.json"; then
  pass
else
  fail "Expected upgrade output to mention settings.json"
fi

print_summary
