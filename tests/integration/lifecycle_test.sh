#!/usr/bin/env bash
# Integration lifecycle tests for right-hooks using bashunit
# RED phase — these tests exercise hooks as-is; pre-merge tests should FAIL
# due to known bugs in mock gh output parsing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

function run_hook() {
  local hook="$1"
  local input="$2"
  echo "$input" | RH_TEST=1 bash ".right-hooks/hooks/$hook" 2>/tmp/rh-test-stderr
  return $?
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
  mkdir -p "$TEST_DIR/bin"
  cp "$SCRIPT_DIR/mock-gh.sh" "$TEST_DIR/bin/gh"
  chmod +x "$TEST_DIR/bin/gh"
  export PATH="$TEST_DIR/bin:$PATH"
}

function tear_down_after_script() {
  rm -rf "$TEST_DIR"
}

function set_up() {
  cd "$TEST_DIR" || exit 1
  # Reset mock state
  export MOCK_PR_EXISTS=0
  export MOCK_PR_NUMBER=1
  export MOCK_HAS_REVIEW=0
  export MOCK_HAS_QA=0
  export MOCK_HAS_LEARNINGS=0
  export MOCK_HAS_DESIGN_DOC=0
  export MOCK_HAS_EXEC_PLAN=0
  export MOCK_CI_FAILING=0
  export MOCK_DOD_INCOMPLETE=0
  # Clean up branches from previous tests (ignore errors)
  git checkout -q master 2>/dev/null || true
}

# --- Test 1: session-start injects branch context ---
function test_session_start_injects_context() {
  git checkout -qb feat/test-feature-ss 2>/dev/null || git checkout -q feat/test-feature-ss
  export MOCK_PR_EXISTS=0
  local output
  output=$(echo '{}' | RH_TEST=1 bash .right-hooks/hooks/session-start.sh 2>/dev/null)
  assert_contains "feat/test-feature-ss" "$output"
}

# --- Test 2: pre-pr-create blocks without design doc ---
function test_pre_pr_create_blocks_without_design_doc() {
  git checkout -qb feat/test-feature-prblk 2>/dev/null || git checkout -q feat/test-feature-prblk
  run_hook "pre-pr-create.sh" '{"tool_input":{"command":"gh pr create --title test"}}'
  assert_exit_code "2"
  assert_contains "design" "$(cat /tmp/rh-test-stderr)"
}

# --- Test 3: pre-pr-create passes with docs ---
function test_pre_pr_create_passes_with_docs() {
  git checkout -qb feat/test-feature-prpass 2>/dev/null || git checkout -q feat/test-feature-prpass
  mkdir -p docs/designs docs/exec-plans
  printf "# Design\n## Problem\ntest\n## Alternatives\n## Decision\n" > docs/designs/test.md
  printf "# Plan\n## Steps\n## Definition of Done\n- [ ] done\n" > docs/exec-plans/test.md
  git add -A && git commit -qm "add docs"
  run_hook "pre-pr-create.sh" '{"tool_input":{"command":"gh pr create --title test"}}'
  assert_exit_code "0"
}

# --- Test 4: pre-merge blocks without review ---
function test_pre_merge_blocks_without_review() {
  git checkout -qb feat/test-feature-mr1 2>/dev/null || git checkout -q feat/test-feature-mr1
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=42
  export MOCK_HAS_REVIEW=0 MOCK_HAS_QA=0 MOCK_HAS_LEARNINGS=0
  export MOCK_CI_FAILING=0 MOCK_DOD_INCOMPLETE=0
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 42"}}'
  assert_exit_code "2"
}

# --- Test 5: pre-merge blocks with review but no QA ---
function test_pre_merge_blocks_with_review_but_no_qa() {
  git checkout -qb feat/test-feature-mr2 2>/dev/null || git checkout -q feat/test-feature-mr2
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=42
  export MOCK_HAS_REVIEW=1 MOCK_HAS_QA=0 MOCK_HAS_LEARNINGS=0
  export MOCK_CI_FAILING=0 MOCK_DOD_INCOMPLETE=0
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 42"}}'
  assert_exit_code "2"
}

# --- Test 6: pre-merge passes with all gates ---
function test_pre_merge_passes_with_all_gates() {
  git checkout -qb feat/test-feature-mr3 2>/dev/null || git checkout -q feat/test-feature-mr3
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=42
  export MOCK_HAS_REVIEW=1 MOCK_HAS_QA=1 MOCK_HAS_LEARNINGS=1
  export MOCK_CI_FAILING=0 MOCK_DOD_INCOMPLETE=0
  mkdir -p docs/retros
  printf "# Learnings\n## Orchestrator\n### What Went Wrong\n- nothing\n### Rules to Extract\n- always test\n" > docs/retros/test-learnings.md
  git add -A && git commit -qm "add learnings"
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 42"}}'
  assert_exit_code "0"
}

# --- Test 7: stop-check allows when complete ---
function test_stop_check_allows_when_complete() {
  git checkout -qb feat/test-feature-sc 2>/dev/null || git checkout -q feat/test-feature-sc
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=42
  export MOCK_HAS_REVIEW=1 MOCK_HAS_QA=1
  run_hook "stop-check.sh" '{}'
  assert_exit_code "0"
}

# --- Test 8: pre-push blocks main ---
function test_pre_push_blocks_main() {
  git checkout -q main
  run_hook "pre-push-master.sh" '{"tool_input":{"command":"git push origin main"}}'
  assert_exit_code "2"
}

# --- Test 9: pre-merge blocks CI failing ---
function test_pre_merge_blocks_ci_failing() {
  git checkout -qb fix/ci-test 2>/dev/null || git checkout -q fix/ci-test
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=43
  export MOCK_CI_FAILING=1
  export MOCK_HAS_REVIEW=1 MOCK_HAS_QA=1 MOCK_HAS_LEARNINGS=1
  export MOCK_DOD_INCOMPLETE=0
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 43"}}'
  assert_exit_code "2"
  assert_contains "CI" "$(cat /tmp/rh-test-stderr)"
}

# --- Test 10: pre-merge blocks DoD incomplete ---
function test_pre_merge_blocks_dod_incomplete() {
  git checkout -qb fix/dod-test 2>/dev/null || git checkout -q fix/dod-test
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=44
  export MOCK_CI_FAILING=0 MOCK_DOD_INCOMPLETE=1
  export MOCK_HAS_REVIEW=1 MOCK_HAS_QA=1 MOCK_HAS_LEARNINGS=1
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 44"}}'
  assert_exit_code "2"
}

# --- Test 11: light profile skips review ---
function test_light_profile_skips_review() {
  node "$PROJECT_DIR/bin/right-hooks.js" profile light >/dev/null 2>&1
  git checkout -qb docs/readme-update 2>/dev/null || git checkout -q docs/readme-update
  export MOCK_PR_EXISTS=1 MOCK_PR_NUMBER=45
  export MOCK_HAS_REVIEW=0 MOCK_HAS_QA=0 MOCK_HAS_LEARNINGS=0
  export MOCK_CI_FAILING=0 MOCK_DOD_INCOMPLETE=0
  run_hook "pre-merge.sh" '{"tool_input":{"command":"gh pr merge 45"}}'
  local exit_code=$?
  # Restore strict profile for subsequent tests
  node "$PROJECT_DIR/bin/right-hooks.js" profile strict >/dev/null 2>&1
  assert_exit_code "0"
}

# --- Test 12: agent cannot self-override ---
function test_agent_cannot_self_override() {
  run_hook "block-agent-override.sh" '{"tool_input":{"command":"npx right-hooks override --gate=qa --reason=skip"}}'
  assert_exit_code "2"
}
