#!/usr/bin/env bash
# Integration test: full Claude Code lifecycle with Right Hooks
# Simulates: SessionStart → edits → PR create → review/QA → merge → post-merge
set -euo pipefail

# Helper: run hook and capture exit code without triggering set -e
run_hook_test() {
  local hook="$1"
  local input="$2"
  local stderr_file="${3:-/dev/null}"
  echo "$input" | bash ".right-hooks/hooks/$hook" >/dev/null 2>"$stderr_file" && EXIT=0 || EXIT=$?
}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../helpers.sh"
setup_test_env

BIN="$(cd "$SCRIPT_DIR/../../" && pwd)/bin/right-hooks.js"
HOOKS_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)/hooks"

# ── Setup: mock gh + init project ──
mkdir -p "$TEST_TMPDIR/bin"
cp "$SCRIPT_DIR/mock-gh.sh" "$TEST_TMPDIR/bin/gh"
chmod +x "$TEST_TMPDIR/bin/gh"
export PATH="$TEST_TMPDIR/bin:$PATH"

cd "$TEST_TMPDIR"
git init -q
git commit --allow-empty -m "init" -q
echo '{}' > tsconfig.json
RH_TEST=1 node "$BIN" init --yes >/dev/null 2>&1

# Copy hooks from source (init installs from package root)
cp "$HOOKS_DIR"/*.sh .right-hooks/hooks/

# Set strict profile
node "$BIN" profile strict >/dev/null 2>&1

# ══════════════════════════════════════════
# Scenario 1: feat/ branch — full lifecycle
# ══════════════════════════════════════════

git checkout -qb feat/test-feature

# ── Step 1: SessionStart ──
describe "session-start injects context on feat/ branch"
export MOCK_PR_EXISTS=0
OUTPUT=$(echo '{}' | bash .right-hooks/hooks/session-start.sh 2>/dev/null)
if echo "$OUTPUT" | grep -q "feat/test-feature"; then
  pass
else
  fail "Expected branch name in session context: $OUTPUT"
fi

# ── Step 2: post-edit-check after editing a .ts file ──
describe "post-edit-check runs validation on .ts edit"
mkdir -p src
echo "const x: number = 'wrong'" > src/index.ts
run_hook_test "post-edit-check.sh" '{"tool_result":{"file_path":"src/index.ts"}}'
EXIT=$?
# Preset has tsc validation — should either pass (no tsc installed) or block
if [ "$EXIT" -eq 0 ] || [ "$EXIT" -eq 2 ]; then
  pass
else
  fail "Expected exit 0 or 2, got $EXIT"
fi

# ── Step 3: PR create WITHOUT design doc → BLOCKED ──
describe "pre-pr-create blocks feat/ PR without design doc"
run_hook_test "pre-pr-create.sh" '{"tool_input":{"command":"gh pr create --title test"}}' "$TEST_TMPDIR/stderr"
EXIT=$?
if [ "$EXIT" -eq 2 ]; then
  pass
else
  fail "Expected exit 2 (blocked), got $EXIT"
fi

describe "pre-pr-create stderr mentions missing design doc"
if grep -qi "design doc\|planning" "$TEST_TMPDIR/stderr"; then
  pass
else
  fail "Expected design doc mention in stderr"
fi

# ── Step 4: Add design doc + exec plan → PR create PASSES ──
mkdir -p docs/designs docs/exec-plans
cat > docs/designs/test-feature.md << 'DOC'
# Design Doc: Test Feature
## Problem Statement
Testing the lifecycle
## Alternatives Considered
### Option A
## Decision
Chosen: A
DOC
cat > docs/exec-plans/test-feature.md << 'DOC'
# Execution Plan: Test Feature
## Implementation Steps
## Definition of Done
- [ ] All tests pass
DOC
git add -A && git commit -qm "add planning artifacts"

describe "pre-pr-create passes with design doc + exec plan"
export MOCK_HAS_DESIGN_DOC=1
export MOCK_HAS_EXEC_PLAN=1
run_hook_test "pre-pr-create.sh" '{"tool_input":{"command":"gh pr create --title test"}}'
EXIT=$?
if [ "$EXIT" -eq 0 ]; then
  pass
else
  fail "Expected exit 0, got $EXIT"
fi

# ── Step 5: Try merge WITHOUT review/QA → BLOCKED ──
describe "pre-merge blocks without review comment"
export MOCK_PR_EXISTS=1
export MOCK_PR_NUMBER=42
export MOCK_HAS_REVIEW=0
export MOCK_HAS_QA=0
export MOCK_HAS_LEARNINGS=0
export MOCK_CI_FAILING=0
export MOCK_DOD_INCOMPLETE=0
run_hook_test "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 42"}}' "$TEST_TMPDIR/stderr"
EXIT=$?
if [ "$EXIT" -eq 2 ]; then
  pass
else
  fail "Expected exit 2 (blocked), got $EXIT"
fi

# ── Step 6: Add review → still blocked (no QA, no learnings) ──
describe "pre-merge still blocks with review but no QA"
export MOCK_HAS_REVIEW=1
run_hook_test "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 42"}}' "$TEST_TMPDIR/stderr"
EXIT=$?
if [ "$EXIT" -eq 2 ]; then
  pass
else
  fail "Expected exit 2 (still blocked), got $EXIT"
fi

describe "pre-merge stderr mentions QA or learnings"
if grep -qi "qa\|learnings" "$TEST_TMPDIR/stderr"; then
  pass
else
  fail "Expected QA/learnings mention in stderr"
fi

# ── Step 7: Add QA + learnings → merge PASSES ──
describe "pre-merge passes with all gates satisfied"
export MOCK_HAS_QA=1
export MOCK_HAS_LEARNINGS=1
mkdir -p docs/retros
cat > docs/retros/test-feature-learnings.md << 'DOC'
# Learnings: Test Feature
## Orchestrator
### What Went Wrong
- Nothing major
### Rules to Extract
- Always test the lifecycle end-to-end
DOC
git add -A && git commit -qm "add learnings"
run_hook_test "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 42"}}'
EXIT=$?
if [ "$EXIT" -eq 0 ]; then
  pass
else
  fail "Expected exit 0 (all gates passed), got $EXIT"
fi

# ── Step 8: stop-check allows stop after workflow complete ──
describe "stop-check allows stop when review + QA exist"
run_hook_test "stop-check.sh" '{}'
EXIT=$?
if [ "$EXIT" -eq 0 ]; then
  pass
else
  fail "Expected exit 0 (can stop), got $EXIT"
fi

# ── Step 9: push to main → BLOCKED ──
describe "pre-push blocks direct push to main"
git checkout -q main 2>/dev/null || git checkout -qb main
run_hook_test "pre-push-master.sh" '{"tool_input":{"command":"git push origin main"}}' "$TEST_TMPDIR/stderr"
EXIT=$?
if [ "$EXIT" -eq 2 ]; then
  pass
else
  fail "Expected exit 2 (blocked), got $EXIT"
fi

# ══════════════════════════════════════════
# Scenario 2: CI failing → merge blocked
# ══════════════════════════════════════════

git checkout -qb fix/ci-test 2>/dev/null || git checkout -q fix/ci-test

describe "pre-merge blocks when CI is failing"
export MOCK_CI_FAILING=1
export MOCK_HAS_REVIEW=1
export MOCK_HAS_QA=1
export MOCK_HAS_LEARNINGS=1
export MOCK_PR_EXISTS=1
export MOCK_PR_NUMBER=43
run_hook_test "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 43"}}' "$TEST_TMPDIR/stderr"
EXIT=$?
if [ "$EXIT" -eq 2 ]; then
  pass
else
  fail "Expected exit 2 (CI failing), got $EXIT"
fi

describe "pre-merge stderr mentions CI"
if grep -qi "ci\|failing\|pending" "$TEST_TMPDIR/stderr"; then
  pass
else
  fail "Expected CI mention in stderr"
fi

# ══════════════════════════════════════════
# Scenario 3: DoD incomplete → merge blocked
# ══════════════════════════════════════════

describe "pre-merge blocks when DoD has unchecked items"
export MOCK_CI_FAILING=0
export MOCK_DOD_INCOMPLETE=1
run_hook_test "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 43"}}' "$TEST_TMPDIR/stderr"
EXIT=$?
if [ "$EXIT" -eq 2 ]; then
  pass
else
  fail "Expected exit 2 (DoD incomplete), got $EXIT"
fi

# ══════════════════════════════════════════
# Scenario 4: light profile skips review/QA
# ══════════════════════════════════════════

git checkout -qb docs/readme-update 2>/dev/null || git checkout -q docs/readme-update

describe "light profile allows merge without review/QA"
node "$BIN" profile light >/dev/null 2>&1
export MOCK_PR_EXISTS=1
export MOCK_PR_NUMBER=44
export MOCK_HAS_REVIEW=0
export MOCK_HAS_QA=0
export MOCK_HAS_LEARNINGS=0
export MOCK_CI_FAILING=0
export MOCK_DOD_INCOMPLETE=0
run_hook_test "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 44"}}'
EXIT=$?
if [ "$EXIT" -eq 0 ]; then
  pass
else
  fail "Expected exit 0 (light profile), got $EXIT"
fi

# ══════════════════════════════════════════
# Scenario 5: override bypasses a gate
# ══════════════════════════════════════════

git checkout -q feat/test-feature

describe "override allows bypassing a blocked gate"
node "$BIN" profile strict >/dev/null 2>&1
export MOCK_PR_EXISTS=1
export MOCK_PR_NUMBER=42
export MOCK_HAS_REVIEW=1
export MOCK_HAS_QA=0  # QA missing
export MOCK_HAS_LEARNINGS=1
export MOCK_CI_FAILING=0
export MOCK_DOD_INCOMPLETE=0
# Create override for QA gate
node "$BIN" override --gate=qa --pr=42 --reason="Manual testing done" >/dev/null 2>&1
run_hook_test "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 42"}}'
EXIT=$?
if [ "$EXIT" -eq 0 ]; then
  pass
else
  fail "Expected exit 0 (QA overridden), got $EXIT"
fi

# ══════════════════════════════════════════
# Scenario 6: agent can't self-override
# ══════════════════════════════════════════

describe "block-agent-override prevents agent from calling override"
run_hook_test "block-agent-override.sh" '{"tool_input":{"command":"npx right-hooks override --gate=qa --reason=skip"}}' "$TEST_TMPDIR/stderr"
EXIT=$?
if [ "$EXIT" -eq 2 ]; then
  pass
else
  fail "Expected exit 2 (blocked), got $EXIT"
fi

print_summary
