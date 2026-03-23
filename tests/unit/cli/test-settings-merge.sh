#!/usr/bin/env bash
# Tests for: src/settings-merge.js — shared settings.json merge logic
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../" && pwd)"

echo "cli/settings-merge"

# Helper: run a node one-liner that exercises the merge function
run_merge() {
  local existing="$1"
  local shipped="$2"
  node -e "
    const { mergeSettings } = require('$PROJECT_DIR/src/settings-merge');
    const existing = JSON.parse(process.argv[1]);
    const shipped = JSON.parse(process.argv[2]);
    const result = mergeSettings(existing, shipped);
    process.stdout.write(JSON.stringify(result, null, 2));
  " "$existing" "$shipped"
}

# --- Test: empty existing gets all shipped hooks ---
describe "merges all hooks into empty existing settings"
RESULT=$(run_merge '{}' '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"hook-a.sh"}]}]}}')
if echo "$RESULT" | node -e "
  const r = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  process.exit(r.hooks && r.hooks.PreToolUse && r.hooks.PreToolUse.length === 1 ? 0 : 1);
"; then
  pass
else
  fail "Expected PreToolUse to have 1 entry"
fi

# --- Test: duplicate commands are not added ---
describe "skips duplicate hook commands"
EXISTING='{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"stop-check.sh"}]}]}}'
SHIPPED='{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"stop-check.sh"}]}]}}'
RESULT=$(run_merge "$EXISTING" "$SHIPPED")
COUNT=$(echo "$RESULT" | node -e "
  const r = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  const cmds = r.hooks.Stop.flatMap(e => (e.hooks||[]).map(h => h.command));
  process.stdout.write(String(cmds.length));
")
if [ "$COUNT" = "1" ]; then
  pass
else
  fail "Expected 1 command, got $COUNT"
fi

# --- Test: new hook events are added alongside existing ones ---
describe "adds new hook events without removing existing"
EXISTING='{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"stop.sh"}]}]}}'
SHIPPED='{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"session.sh"}]}]}}'
RESULT=$(run_merge "$EXISTING" "$SHIPPED")
if echo "$RESULT" | node -e "
  const r = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  process.exit(r.hooks.Stop && r.hooks.SessionStart ? 0 : 1);
"; then
  pass
else
  fail "Expected both Stop and SessionStart events"
fi

# --- Test: new commands within existing events are appended ---
describe "appends new commands to existing hook events"
EXISTING='{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"hook-a.sh"}]}]}}'
SHIPPED='{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"hook-b.sh"}]}]}}'
RESULT=$(run_merge "$EXISTING" "$SHIPPED")
COUNT=$(echo "$RESULT" | node -e "
  const r = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  const cmds = r.hooks.PreToolUse.flatMap(e => (e.hooks||[]).map(h => h.command));
  process.stdout.write(String(cmds.length));
")
if [ "$COUNT" = "2" ]; then
  pass
else
  fail "Expected 2 commands, got $COUNT"
fi

# --- Test: existing non-hooks fields are preserved ---
describe "preserves non-hooks fields in existing settings"
EXISTING='{"hooks":{},"customField":"keep-me"}'
SHIPPED='{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"s.sh"}]}]}}'
RESULT=$(run_merge "$EXISTING" "$SHIPPED")
if echo "$RESULT" | node -e "
  const r = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  process.exit(r.customField === 'keep-me' ? 0 : 1);
"; then
  pass
else
  fail "Expected customField to be preserved"
fi

# --- Test: does not mutate input objects ---
describe "does not mutate input objects (immutability)"
node -e "
  const { mergeSettings } = require('$PROJECT_DIR/src/settings-merge');
  const existing = { hooks: { Stop: [{ hooks: [{ type: 'command', command: 'a.sh' }] }] } };
  const shipped = { hooks: { Stop: [{ hooks: [{ type: 'command', command: 'b.sh' }] }] } };
  const existingBefore = JSON.stringify(existing);
  const shippedBefore = JSON.stringify(shipped);
  mergeSettings(existing, shipped);
  if (JSON.stringify(existing) !== existingBefore) {
    console.error('existing was mutated');
    process.exit(1);
  }
  if (JSON.stringify(shipped) !== shippedBefore) {
    console.error('shipped was mutated');
    process.exit(1);
  }
  process.exit(0);
"
if [ $? -eq 0 ]; then
  pass
else
  fail "Input objects were mutated"
fi

print_summary
