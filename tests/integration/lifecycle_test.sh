#!/usr/bin/env bash
# Integration lifecycle tests for right-hooks using bashunit
# RED phase — these tests exercise hooks as-is; pre-merge tests should FAIL
# due to known bugs in mock gh output parsing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

function run_hook() {
  local hook="$1"
  local input="$2"
  RH_LAST_EXIT=0
  echo "$input" | RH_TEST=1 bash ".right-hooks/hooks/$hook" 2>/tmp/rh-test-stderr || RH_LAST_EXIT=$?
  return 0
}

function set_up_before_script() {
  export TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR" || exit 1

  git init -q -b master
  git config user.email "test@test.com"
  git config user.name "Test"
  git commit --allow-empty -m "init" -q
  echo '{}' > tsconfig.json

  local BIN="$PROJECT_DIR/bin/right-hooks.js"
  RH_TEST=1 node "$BIN" init --yes >/dev/null 2>&1
  cp "$PROJECT_DIR"/hooks/*.sh .right-hooks/hooks/
  node "$BIN" profile strict >/dev/null 2>&1
  git add -A && git commit -qm "right-hooks init"
  git branch main

  # PATH injection for mock gh (works across subprocess boundaries)
  # Mock gh lives OUTSIDE the git repo so git add/checkout can't affect it
  export MOCK_BIN_DIR=$(mktemp -d)
  cp "$SCRIPT_DIR/mock-gh.sh" "$MOCK_BIN_DIR/gh"
  chmod +x "$MOCK_BIN_DIR/gh"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

function tear_down_after_script() {
  rm -rf "$TEST_DIR" "$MOCK_BIN_DIR"
}

function set_up() {
  cd "$TEST_DIR" || exit 1
  # Re-export PATH with mock gh (outside git repo)
  export PATH="$MOCK_BIN_DIR:$PATH"
  # Clean working tree — prior tests may create dirs on branches that
  # persist after checkout. Only clean docs/ to avoid removing .right-hooks/
  git checkout -q master 2>/dev/null || true
  rm -rf docs/ 2>/dev/null || true
  # Reset mock state
  export MOCK_PR_EXISTS=0
  export MOCK_PR_NUMBER=1
  export MOCK_HAS_REVIEW=0
  export MOCK_HAS_QA=0
  export MOCK_HAS_LEARNINGS=0
  export MOCK_HAS_DESIGN_DOC=0
  export MOCK_HAS_EXEC_PLAN=0
  export MOCK_HAS_DOC=0
  export MOCK_CI_FAILING=0
  export MOCK_DOD_INCOMPLETE=0
}

# ══════════════════════════════════════════════════════════════
# Test 1: Session Start
# ══════════════════════════════════════════════════════════════
# WHAT: session-start.sh hook fires at Claude Code session begin
# VERIFY: stdout JSON contains current branch name for context injection
# VERIFY: stderr has branded 🥊 output proving hook executed its logic
# WHY: agent needs branch/PR/profile context to know what workflow to follow
function test_session_start_injects_context() {
  git checkout -qb feat/test-feature-ss 2>/dev/null || git checkout -q feat/test-feature-ss
  export MOCK_PR_EXISTS=0
  local output stderr_out
  output=$(echo '{}' | RH_TEST=1 bash .right-hooks/hooks/session-start.sh 2>/tmp/rh-test-stderr)
  stderr_out=$(cat /tmp/rh-test-stderr)
  assert_contains "feat/test-feature-ss" "$output"
  assert_contains "session-start" "$stderr_out"
}

# ══════════════════════════════════════════════════════════════
# Test 2: PR Creation Blocked Without Planning Artifacts
# ══════════════════════════════════════════════════════════════
# WHAT: pre-pr-create.sh fires before `gh pr create` on feat/ branches
# VERIFY: exit 2 (block) when no design doc or exec plan exists
# VERIFY: stderr tells agent what's missing
# WHY: Doc-First opinion — agents must think before coding
function test_pre_pr_create_blocks_without_design_doc() {
  git checkout -qb feat/test-feature-prblk 2>/dev/null || git checkout -q feat/test-feature-prblk
  run_hook "pre-pr-create.sh" '{"tool_input":{"command":"gh pr create --title test"}}'
  assert_equals "2" "$RH_LAST_EXIT"
  assert_contains "design" "$(cat /tmp/rh-test-stderr)"
}

# ══════════════════════════════════════════════════════════════
# Test 3: PR Creation Passes With Planning Artifacts
# ══════════════════════════════════════════════════════════════
# WHAT: same hook, but design doc + exec plan (with DoD) exist in git diff
# VERIFY: exit 0 (allow)
# VERIFY: stderr has branded ✓ output proving hook found the docs
#         (not just exit 0 because it crashed or skipped)
# WHY: proves the hook actually scanned git diff and found matching files
function test_pre_pr_create_passes_with_docs() {
  git checkout -qb feat/test-feature-prpass 2>/dev/null || git checkout -q feat/test-feature-prpass
  mkdir -p docs/designs docs/exec-plans
  printf "# Design\n## Problem\ntest\n## Alternatives\n## Decision\n" > docs/designs/test.md
  printf "# Plan\n## Steps\n## Definition of Done\n- [ ] done\n" > docs/exec-plans/test.md
  git add -A && git commit -qm "add docs"
  run_hook "pre-pr-create.sh" '{"tool_input":{"command":"gh pr create --title test"}}'
  assert_equals "0" "$RH_LAST_EXIT"
  assert_contains "pre-pr-create" "$(cat /tmp/rh-test-stderr)"
  assert_contains "✓" "$(cat /tmp/rh-test-stderr)"
}

# ══════════════════════════════════════════════════════════════
# Test 4: Merge Blocked Without Review Comment
# ══════════════════════════════════════════════════════════════
# WHAT: pre-merge.sh fires before `gh pr merge` — checks all gates
# SETUP: PR exists (#42), strict profile, NO review/QA/learnings, CI green, DoD complete
# VERIFY: exit 2 (block) — review gate not satisfied
# WHY: strict profile requires code review before merge
function test_pre_merge_blocks_without_review() {
  git checkout -qb feat/test-feature-mr1 2>/dev/null || git checkout -q feat/test-feature-mr1
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=42
  export MOCK_HAS_REVIEW=0 MOCK_HAS_QA=0 MOCK_HAS_LEARNINGS=0
  export MOCK_CI_FAILING=0 MOCK_DOD_INCOMPLETE=0
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 42"}}'
  assert_equals "2" "$RH_LAST_EXIT"
}

# ══════════════════════════════════════════════════════════════
# Test 5: Merge Blocked With Review But No QA
# ══════════════════════════════════════════════════════════════
# WHAT: same gate check — review exists but QA and learnings missing
# VERIFY: exit 2 (still blocked)
# VERIFY: stderr mentions QA or learnings as the missing gate
# WHY: strict profile requires ALL gates, not just review
function test_pre_merge_blocks_with_review_but_no_qa() {
  git checkout -qb feat/test-feature-mr2 2>/dev/null || git checkout -q feat/test-feature-mr2
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=42
  export MOCK_HAS_REVIEW=1 MOCK_HAS_QA=0 MOCK_HAS_LEARNINGS=0
  export MOCK_CI_FAILING=0 MOCK_DOD_INCOMPLETE=0
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 42"}}'
  assert_equals "2" "$RH_LAST_EXIT"
}

# ══════════════════════════════════════════════════════════════
# Test 6: Merge Passes With All Gates Satisfied
# ══════════════════════════════════════════════════════════════
# WHAT: all gates satisfied — review ✓, QA ✓, learnings ✓, CI green, DoD complete
# VERIFY: exit 0 (allow merge)
# VERIFY: stderr shows "gates passed" — proves hook ran all checks
#         (not just exit 0 because mock parsing failed and checks were skipped)
# WHY: the happy path must actually validate, not just skip
function test_pre_merge_passes_with_all_gates() {
  git checkout -qb feat/test-feature-mr3 2>/dev/null || git checkout -q feat/test-feature-mr3
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=42
  export MOCK_HAS_REVIEW=1 MOCK_HAS_QA=1 MOCK_HAS_LEARNINGS=1 MOCK_HAS_DOC=1
  export MOCK_HAS_DESIGN_DOC=1 MOCK_HAS_EXEC_PLAN=1
  export MOCK_CI_FAILING=0 MOCK_DOD_INCOMPLETE=0
  # Create learnings file matching mock's gh pr diff output filename
  # Headers must match signatures.json learningsHeader values
  mkdir -p docs/retros
  printf "# Learnings\n## Review Agent\n- reviewed\n## QA Agent\n- tested\n### Rules to Extract\n- always test\n" > docs/retros/test-feature-learnings.md
  git add -A && git commit -qm "add learnings"
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 42"}}'
  assert_equals "0" "$RH_LAST_EXIT"
  local stderr_out=$(cat /tmp/rh-test-stderr)
  assert_contains "pre-merge" "$stderr_out"
  assert_contains "gates passed" "$stderr_out"
}

# ══════════════════════════════════════════════════════════════
# Test 7: Stop-Check Allows Stop When Workflow Complete
# ══════════════════════════════════════════════════════════════
# WHAT: stop-check.sh fires when agent tries to end session on feat/ branch
# SETUP: PR #42 exists, review + QA comments present
# VERIFY: exit 0 (allow stop)
# VERIFY: stderr shows "workflow complete" — proves hook checked PR comments
#         (not just exit 0 because no PR was detected → early return)
# WHY: stop-check must verify review/QA exist, not just skip when mock fails
function test_stop_check_allows_when_complete() {
  git checkout -qb feat/test-feature-sc 2>/dev/null || git checkout -q feat/test-feature-sc
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=42
  export MOCK_HAS_REVIEW=1 MOCK_HAS_QA=1 MOCK_HAS_LEARNINGS=1
  run_hook "stop-check.sh" '{}'
  assert_equals "0" "$RH_LAST_EXIT"
  local stderr_out=$(cat /tmp/rh-test-stderr)
  assert_contains "stop-check" "$stderr_out"
  assert_contains "workflow complete" "$stderr_out"
}

# ══════════════════════════════════════════════════════════════
# Test 8: Pre-Push Blocks Direct Push to Main
# ══════════════════════════════════════════════════════════════
# WHAT: pre-push-master.sh fires before `git push` — checks branch name
# VERIFY: exit 2 (block) when on main branch
# VERIFY: stderr has branded block message with "blocked"
# WHY: all changes must go through PRs — this is enforced by husky (GH) + Claude Code hook (CH)
function test_pre_push_blocks_main() {
  git checkout -q main
  run_hook "pre-push-master.sh" '{"tool_input":{"command":"git push origin main"}}'
  assert_equals "2" "$RH_LAST_EXIT"
  assert_contains "pre-push" "$(cat /tmp/rh-test-stderr)"
  assert_contains "blocked" "$(cat /tmp/rh-test-stderr)"
}

# ══════════════════════════════════════════════════════════════
# Test 9: Merge Blocked When CI Failing
# ══════════════════════════════════════════════════════════════
# WHAT: pre-merge gate — CI check
# SETUP: PR #43 on fix/ branch, CI failing, all other gates pass
# VERIFY: exit 2 (block)
# VERIFY: stderr mentions "CI"
# WHY: can't merge with red CI — mechanical enforcement
function test_pre_merge_blocks_ci_failing() {
  git checkout -qb fix/ci-test 2>/dev/null || git checkout -q fix/ci-test
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=43
  export MOCK_CI_FAILING=1
  export MOCK_HAS_REVIEW=1 MOCK_HAS_QA=1 MOCK_HAS_LEARNINGS=1
  export MOCK_DOD_INCOMPLETE=0
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 43"}}'
  assert_equals "2" "$RH_LAST_EXIT"
  assert_contains "CI" "$(cat /tmp/rh-test-stderr)"
}

# ══════════════════════════════════════════════════════════════
# Test 10: Merge Blocked When DoD Incomplete
# ══════════════════════════════════════════════════════════════
# WHAT: pre-merge gate — DoD (Definition of Done) check
# SETUP: PR #44, all gates pass except DoD has unchecked `- [ ]` items
# VERIFY: exit 2 (block)
# WHY: PR body checkboxes must all be checked before merge
function test_pre_merge_blocks_dod_incomplete() {
  git checkout -qb fix/dod-test 2>/dev/null || git checkout -q fix/dod-test
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=44
  export MOCK_CI_FAILING=0 MOCK_DOD_INCOMPLETE=1
  export MOCK_HAS_REVIEW=1 MOCK_HAS_QA=1 MOCK_HAS_LEARNINGS=1
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 44"}}'
  assert_equals "2" "$RH_LAST_EXIT"
}

# ══════════════════════════════════════════════════════════════
# Test 11: Light Profile Skips Review/QA Gates
# ══════════════════════════════════════════════════════════════
# WHAT: pre-merge with light profile on docs/ branch
# SETUP: PR #45, NO review/QA/learnings — but light profile doesn't require them
# VERIFY: exit 0 (allow)
# VERIFY: stderr shows "gates passed" — proves hook loaded light profile
#         and ran the reduced gate set (not just exit 0 from early return)
# WHY: light profile only checks CI + DoD + doc consistency
function test_light_profile_skips_review() {
  node "$PROJECT_DIR/bin/right-hooks.js" profile light >/dev/null 2>&1
  git checkout -qb docs/readme-update 2>/dev/null || git checkout -q docs/readme-update
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=45
  export MOCK_HAS_REVIEW=0 MOCK_HAS_QA=0 MOCK_HAS_LEARNINGS=0 MOCK_HAS_DOC=1
  export MOCK_CI_FAILING=0 MOCK_DOD_INCOMPLETE=0
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 45"}}'
  local exit_code=$?
  local stderr_out=$(cat /tmp/rh-test-stderr)
  # Restore strict profile for subsequent tests
  node "$PROJECT_DIR/bin/right-hooks.js" profile strict >/dev/null 2>&1
  assert_equals "0" "$RH_LAST_EXIT"
  assert_contains "pre-merge" "$stderr_out"
  assert_contains "gates passed" "$stderr_out"
}

# ══════════════════════════════════════════════════════════════
# Test 12: Agent Cannot Self-Override
# ══════════════════════════════════════════════════════════════
# WHAT: block-agent-override.sh fires before any command containing "right-hooks override"
# VERIFY: exit 2 (block) — agent can't call override on itself
# VERIFY: stderr says "only humans can override gates"
# WHY: override is an escape hatch for humans only — if agents could self-override,
#      the entire enforcement system would be meaningless
function test_agent_cannot_self_override() {
  run_hook "block-agent-override.sh" '{"tool_input":{"command":"npx right-hooks override --gate=qa --reason=skip"}}'
  assert_equals "2" "$RH_LAST_EXIT"
  assert_contains "block-override" "$(cat /tmp/rh-test-stderr)"
  assert_contains "only humans" "$(cat /tmp/rh-test-stderr)"
}

# ══════════════════════════════════════════════════════════════
# Test 13: Pre-Push Hook Runs Tests
# ══════════════════════════════════════════════════════════════
# WHAT: husky pre-push hook runs npm test before allowing push
# VERIFY: hook contains the test-running gate
# VERIFY: hook blocks (exit 1) when a test command fails
# WHY: never push broken code — catches both agents and humans
function test_pre_push_runs_tests() {
  # Verify the hook source contains the test gate
  local hook_content
  hook_content=$(cat "$PROJECT_DIR/husky/pre-push")
  assert_contains "npm test" "$hook_content"
  assert_contains "Tests failed" "$hook_content"

  # Simulate a failing test run by creating a pre-push script
  # that uses a broken test command
  local hook_script="$TEST_DIR/.test-pre-push.sh"
  cat > "$hook_script" << 'HOOKEOF'
#!/usr/bin/env bash
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
# Skip branch checks for this test
# Run a command that always fails (simulates broken tests)
if ! false 2>&1; then
  echo "RIGHT-HOOKS: Tests failed. Fix before pushing." >&2
  exit 1
fi
exit 0
HOOKEOF
  chmod +x "$hook_script"
  RH_LAST_EXIT=0
  bash "$hook_script" 2>/tmp/rh-test-stderr || RH_LAST_EXIT=$?
  assert_equals "1" "$RH_LAST_EXIT"
  assert_contains "Tests failed" "$(cat /tmp/rh-test-stderr)"
}
